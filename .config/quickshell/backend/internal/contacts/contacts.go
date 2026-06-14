// Package contacts parses the local vdirsyncer address book (vCard .vcf files
// under ~/.local/share/contacts) and streams the full contact list to the
// shell, which filters it in the launcher. The list is small, so we ship it
// whole and re-scan on a slow ticker.
package contacts

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/emersion/go-vcard"

	"fenriz/internal/log"
	"fenriz/internal/service"
)

const Name = "contacts"

const refresh = 5 * time.Minute

// Detail is one typed value (an email or phone) plus its label.
type Detail struct {
	Type  string `json:"type"`  // e.g. "Cell", "Home", "Work", "" when unlabelled
	Value string `json:"value"`
}

// Contact is one address-book entry.
type Contact struct {
	UID    string   `json:"uid"`
	Name   string   `json:"name"`
	Org    string   `json:"org"`
	Emails []Detail `json:"emails"`
	Phones []Detail `json:"phones"`
}

type Service struct {
	emit service.Emitter
	last []byte
}

func New() *Service { return &Service{} }

func (s *Service) Name() string { return Name }

func (s *Service) Start(ctx context.Context, emit service.Emitter) error {
	s.emit = emit
	go s.run(ctx)
	return nil
}

func (s *Service) run(ctx context.Context) {
	s.tick()
	t := time.NewTicker(refresh)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.tick()
		}
	}
}

func (s *Service) tick() {
	list := s.scan()
	b, err := json.Marshal(list)
	if err != nil {
		log.Warnf("contacts: marshal: %v", err)
		return
	}
	if bytes.Equal(b, s.last) {
		return
	}
	s.last = b
	s.emit(list)
}

func contactsRoot() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".local", "share", "contacts")
}

func (s *Service) scan() []Contact {
	root := contactsRoot()
	if root == "" {
		return []Contact{}
	}

	var out []Contact
	// vdirsyncer stores cards under <root>/<account>/<collection>/*.vcf.
	files, _ := filepath.Glob(filepath.Join(root, "*", "*", "*.vcf"))
	for _, f := range files {
		if c, ok := parseCard(f); ok {
			out = append(out, c)
		}
	}

	sort.Slice(out, func(i, j int) bool {
		return strings.ToLower(out[i].Name) < strings.ToLower(out[j].Name)
	})
	if out == nil {
		out = []Contact{}
	}
	return out
}

func parseCard(path string) (Contact, bool) {
	f, err := os.Open(path)
	if err != nil {
		return Contact{}, false
	}
	defer f.Close()

	card, err := vcard.NewDecoder(f).Decode()
	if err != nil && err != io.EOF {
		return Contact{}, false
	}

	name := strings.TrimSpace(card.PreferredValue(vcard.FieldFormattedName))
	if name == "" {
		if n := card.Name(); n != nil {
			name = strings.TrimSpace(strings.Join([]string{n.GivenName, n.FamilyName}, " "))
		}
	}
	if name == "" {
		return Contact{}, false // anonymous cards aren't searchable
	}

	uid := card.Value(vcard.FieldUID)
	if uid == "" {
		uid = filepath.Base(path)
	}

	return Contact{
		UID:    uid,
		Name:   name,
		Org:    org(card.PreferredValue(vcard.FieldOrganization)),
		Emails: details(card[vcard.FieldEmail]),
		Phones: details(card[vcard.FieldTelephone]),
	}, true
}

// org flattens the structured vCard ORG value (Company;Unit;Subunit) into a
// readable string, dropping the empty trailing components Apple emits.
func org(raw string) string {
	var parts []string
	for _, p := range strings.Split(raw, ";") {
		if p = strings.TrimSpace(p); p != "" {
			parts = append(parts, p)
		}
	}
	return strings.Join(parts, ", ")
}

func details(fields []*vcard.Field) []Detail {
	out := make([]Detail, 0, len(fields))
	for _, f := range fields {
		v := strings.TrimSpace(f.Value)
		if v == "" {
			continue
		}
		out = append(out, Detail{Type: label(f.Params.Types()), Value: v})
	}
	return out
}

// label picks a human label from a vCard TYPE list, ignoring the structural
// markers Apple sprinkles in (pref/voice/internet).
func label(types []string) string {
	for _, t := range types {
		switch strings.ToLower(t) {
		case "pref", "voice", "internet", "":
			continue
		default:
			return titleCase(t)
		}
	}
	return ""
}

// titleCase upper-cases the first rune and lower-cases the rest (e.g. "CELL" ->
// "Cell"). vCard labels are single words, so this is enough.
func titleCase(s string) string {
	if s == "" {
		return ""
	}
	r := []rune(strings.ToLower(s))
	r[0] = []rune(strings.ToUpper(string(r[0])))[0]
	return string(r)
}
