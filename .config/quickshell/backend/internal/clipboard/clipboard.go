// Package clipboard is a Wayland clipboard-history manager. It captures every
// new selection via two `wl-paste --watch` subprocesses (text + image), stores
// each distinct value in an on-disk, binary-safe history, streams the list to
// the shell, and restores a chosen entry with `wl-copy`.
//
// Capture and restore both go through wl-clipboard on purpose: restoring an
// entry means becoming a persistent clipboard *source* (serving the bytes on
// demand for as long as the entry is current), which is exactly what wl-copy's
// lingering process does. Since wl-clipboard is required for restore regardless,
// hand-rolling the wlr-data-control watch half in Go would buy no
// self-sufficiency, so we lean on wl-paste for capture too.
package clipboard

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"time"

	"fenriz/internal/log"
	"fenriz/internal/service"
)

const Name = "clipboard"

// ClipStoreFlag re-invokes this binary as the per-copy store routine; the daemon
// passes it as the `wl-paste --watch` command. See main.go's early branch.
const ClipStoreFlag = "-clip-store"

const (
	maxEntries   = 200     // history cap; oldest pruned past this
	previewLen   = 120     // text preview length (runes)
	maxBlobBytes = 5 << 20 // skip storing values larger than this (big images)
)

// Entry is one history item. ID is the content sha256 (also the blob filename),
// which makes dedup a simple ID compare.
type Entry struct {
	ID      string `json:"id"`
	Mime    string `json:"mime"`
	Preview string `json:"preview"`
	IsImage bool   `json:"isImage"`
	Size    int    `json:"size"`
	TS      int64  `json:"ts"` // unix millis, last seen/copied
}

type payload struct {
	Entries []Entry `json:"entries"`
}

type Service struct {
	emit      service.Emitter
	st        *store
	lastMtime int64
}

func New() *Service { return &Service{} }

func (s *Service) Name() string { return Name }

func (s *Service) Start(ctx context.Context, emit service.Emitter) error {
	s.emit = emit
	s.st = &store{dir: storeDir()}
	if err := os.MkdirAll(s.st.blobsDir(), 0o700); err != nil {
		return err
	}
	if err := s.st.gc(); err != nil {
		log.Warnf("clipboard: gc: %v", err)
	}
	self, err := os.Executable()
	if err != nil {
		return err
	}

	// Two watchers: the default (text-favouring) type, and image/png so an
	// image-only clipboard is caught too. Both feed the same store routine,
	// which sniffs the MIME; dedup-by-hash collapses any overlap.
	go s.watch(ctx, self, nil)
	go s.watch(ctx, self, []string{"--type", "image/png"})
	go s.tick(ctx)

	s.publish() // initial state from disk (history persists across restarts)
	return nil
}

// watch runs a persistent `wl-paste --watch` and restarts it if it dies before
// shutdown. wl-paste invokes `<self> -clip-store` per selection change with the
// new content on stdin.
//
// Pdeathsig ties the watcher's life to ours at the kernel level: if the daemon
// dies by *any* means (incl. SIGKILL on a shell reload, where ctx-based cleanup
// never runs), the watcher gets SIGTERM and exits — no orphans. LockOSThread
// keeps this goroutine's thread (the watcher's parent) alive for the daemon's
// lifetime, so Pdeathsig fires on process death rather than a thread reshuffle.
func (s *Service) watch(ctx context.Context, self string, extra []string) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	for ctx.Err() == nil {
		args := append([]string{}, extra...)
		args = append(args, "--watch", self, ClipStoreFlag)
		cmd := exec.CommandContext(ctx, "wl-paste", args...)
		cmd.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGTERM}

		start := time.Now()
		err := cmd.Run()
		if ctx.Err() != nil {
			return
		}
		if err != nil {
			log.Warnf("clipboard: wl-paste %v exited: %v", extra, err)
		}
		// Pace retries and guard against a fast-exit respawn spin.
		if time.Since(start) < time.Second {
			select {
			case <-ctx.Done():
				return
			case <-time.After(2 * time.Second):
			}
		}
	}
}

// tick re-emits when the on-disk index changes (the -clip-store subprocess is
// the writer, so the daemon learns of new copies by watching the file mtime).
func (s *Service) tick(ctx context.Context) {
	t := time.NewTicker(time.Second)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			fi, err := os.Stat(s.st.indexPath())
			if err != nil {
				continue
			}
			if fi.ModTime().UnixNano() != s.lastMtime {
				s.publish()
			}
		}
	}
}

func (s *Service) publish() {
	entries := s.st.load()
	if entries == nil {
		entries = []Entry{}
	}
	if fi, err := os.Stat(s.st.indexPath()); err == nil {
		s.lastMtime = fi.ModTime().UnixNano()
	}
	s.emit(payload{Entries: entries})
}

// Command implements service.Commander: copy/delete/wipe from the shell.
func (s *Service) Command(name string, raw json.RawMessage) {
	var a struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(raw, &a)

	switch name {
	case "copy":
		s.restore(a.ID)
	case "delete":
		_ = s.st.delete(a.ID)
		s.publish()
	case "wipe":
		_ = s.st.wipe()
		s.publish()
	default:
		log.Warnf("clipboard: unknown command %q", name)
	}
}

// restore puts an entry back on the clipboard. wl-copy forks a process that
// lingers to serve the bytes; changing the selection also re-fires our watcher,
// which dedups and re-fronts the entry.
func (s *Service) restore(id string) {
	e, data, ok := s.st.get(id)
	if !ok {
		return
	}
	cmd := exec.Command("wl-copy", "--type", e.Mime)
	cmd.Stdin = bytes.NewReader(data)
	if err := cmd.Run(); err != nil {
		log.Warnf("clipboard: wl-copy: %v", err)
		return
	}
	_ = s.st.touch(id)
	s.publish()
}

// RunStore is the -clip-store entrypoint: read one clipboard value from stdin
// and append it to the history. Invoked per copy by `wl-paste --watch`.
func RunStore() error {
	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		return err
	}
	if len(data) == 0 || len(data) > maxBlobBytes {
		return nil
	}
	st := &store{dir: storeDir()}
	if err := os.MkdirAll(st.blobsDir(), 0o700); err != nil {
		return err
	}
	return st.add(data)
}

// ---- store ----

type store struct{ dir string }

func storeDir() string {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".local", "state")
	}
	return filepath.Join(base, "fenriz", "clipboard")
}

func (s *store) indexPath() string         { return filepath.Join(s.dir, "index.json") }
func (s *store) blobsDir() string          { return filepath.Join(s.dir, "blobs") }
func (s *store) blobPath(id string) string { return filepath.Join(s.blobsDir(), id) }

// withLock serializes the read-modify-write of the index across the daemon and
// the two -clip-store subprocesses (flock on a dedicated lock file).
func (s *store) withLock(fn func() error) error {
	f, err := os.OpenFile(filepath.Join(s.dir, ".lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	defer syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
	return fn()
}

// load reads the index without locking; save() renames atomically, so a reader
// always sees a complete file.
func (s *store) load() []Entry {
	b, err := os.ReadFile(s.indexPath())
	if err != nil {
		return nil
	}
	var p payload
	if json.Unmarshal(b, &p) != nil {
		return nil
	}
	return p.Entries
}

func (s *store) save(entries []Entry) error {
	b, err := json.Marshal(payload{Entries: entries})
	if err != nil {
		return err
	}
	tmp := s.indexPath() + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, s.indexPath())
}

func (s *store) add(data []byte) error {
	mime := http.DetectContentType(data)
	isImage := strings.HasPrefix(mime, "image/")
	if !isImage {
		if len(bytes.TrimSpace(data)) == 0 {
			return nil // ignore whitespace-only text
		}
		mime = "text/plain;charset=utf-8"
	}
	sum := sha256.Sum256(data)
	id := hex.EncodeToString(sum[:])

	return s.withLock(func() error {
		entries := withoutID(s.load(), id) // dedup
		if err := os.WriteFile(s.blobPath(id), data, 0o600); err != nil {
			return err
		}
		e := Entry{
			ID:      id,
			Mime:    mime,
			Preview: makePreview(data, isImage),
			IsImage: isImage,
			Size:    len(data),
			TS:      time.Now().UnixMilli(),
		}
		entries = append([]Entry{e}, entries...)
		if len(entries) > maxEntries {
			for _, old := range entries[maxEntries:] {
				os.Remove(s.blobPath(old.ID))
			}
			entries = entries[:maxEntries]
		}
		return s.save(entries)
	})
}

func (s *store) get(id string) (Entry, []byte, bool) {
	for _, e := range s.load() {
		if e.ID == id {
			b, err := os.ReadFile(s.blobPath(id))
			if err != nil {
				return Entry{}, nil, false
			}
			return e, b, true
		}
	}
	return Entry{}, nil, false
}

func (s *store) delete(id string) error {
	return s.withLock(func() error {
		entries := withoutID(s.load(), id)
		os.Remove(s.blobPath(id))
		return s.save(entries)
	})
}

func (s *store) wipe() error {
	return s.withLock(func() error {
		os.RemoveAll(s.blobsDir())
		if err := os.MkdirAll(s.blobsDir(), 0o700); err != nil {
			return err
		}
		return s.save([]Entry{})
	})
}

// gc removes blob files no longer referenced by the index: orphans from a crash
// between blob-write and index-save, a corrupted/reset index, or a lowered cap.
// Held under the lock so a concurrent -clip-store can't have its just-written
// blob swept before its index save lands.
func (s *store) gc() error {
	return s.withLock(func() error {
		valid := make(map[string]bool)
		for _, e := range s.load() {
			valid[e.ID] = true
		}
		files, err := os.ReadDir(s.blobsDir())
		if err != nil {
			return err
		}
		for _, f := range files {
			if !f.IsDir() && !valid[f.Name()] {
				os.Remove(s.blobPath(f.Name()))
			}
		}
		return nil
	})
}

// touch moves an entry to the front and refreshes its timestamp.
func (s *store) touch(id string) error {
	return s.withLock(func() error {
		var moved *Entry
		entries := s.load()
		rest := make([]Entry, 0, len(entries))
		for i := range entries {
			if entries[i].ID == id {
				e := entries[i]
				e.TS = time.Now().UnixMilli()
				moved = &e
				continue
			}
			rest = append(rest, entries[i])
		}
		if moved == nil {
			return nil
		}
		return s.save(append([]Entry{*moved}, rest...))
	})
}

func withoutID(entries []Entry, id string) []Entry {
	out := make([]Entry, 0, len(entries))
	for _, e := range entries {
		if e.ID != id {
			out = append(out, e)
		}
	}
	return out
}

func makePreview(data []byte, isImage bool) string {
	if isImage {
		return ""
	}
	flat := strings.Map(func(r rune) rune {
		if r == '\n' || r == '\r' || r == '\t' {
			return ' '
		}
		return r
	}, string(data))
	flat = strings.TrimSpace(flat)
	r := []rune(flat)
	if len(r) > previewLen {
		return string(r[:previewLen]) + "…"
	}
	return flat
}
