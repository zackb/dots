// Package sysinfo samples CPU, memory, disk and temperature and streams them to
// the shell every few seconds. Reads /proc and /sys directly from one goroutine
package sysinfo

import (
	"bufio"
	"context"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"fenriz/internal/service"
)

const Name = "sysinfo"

const interval = 3 * time.Second

// Core is one logical CPU's usage and current frequency (MHz).
type Core struct {
	Index int `json:"index"`
	Pct   int `json:"pct"`
	Freq  int `json:"freq"`
}

// State mirrors the field set the old script emitted, now typed JSON.
type State struct {
	CpuModel    string `json:"cpuModel"`
	OverallCpu  int    `json:"overallCpu"`
	MemPercent  int    `json:"memPercent"`
	DiskPercent int    `json:"diskPercent"`
	TempC       int    `json:"tempC"`
	CpuCores    []Core `json:"cpuCores"`
	MemUsedMB   int    `json:"memUsedMB"`
	MemTotalMB  int    `json:"memTotalMB"`
	MemBuffMB   int    `json:"memBuffMB"`
	MemAvailMB  int    `json:"memAvailMB"`
	DiskUsedMB  int    `json:"diskUsedMB"`
	DiskTotalMB int    `json:"diskTotalMB"`
	DiskAvailMB int    `json:"diskAvailMB"`
}

// cpuTimes is one /proc/stat cpu line: idle (idle+iowait) and total of all fields.
type cpuTimes struct {
	idle, total uint64
}

type Service struct {
	emit     service.Emitter
	cpuModel string
	prev     map[string]cpuTimes // last /proc/stat reading, per "cpu"/"cpuN"
}

func New() *Service {
	return &Service{prev: map[string]cpuTimes{}}
}

func (s *Service) Name() string { return Name }

func (s *Service) Start(ctx context.Context, emit service.Emitter) error {
	s.emit = emit
	s.cpuModel = readCPUModel()
	s.prev = parseStat() // prime the delta baseline so the first emit is meaningful
	go s.run(ctx)
	return nil
}

func (s *Service) run(ctx context.Context) {
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.emit(s.sample())
		}
	}
}

func (s *Service) sample() State {
	overall, cores := s.cpu()
	st := State{
		CpuModel:   s.cpuModel,
		OverallCpu: overall,
		CpuCores:   cores,
		TempC:      readTemp(),
	}
	st.MemPercent, st.MemUsedMB, st.MemTotalMB, st.MemBuffMB, st.MemAvailMB = readMem()
	st.DiskPercent, st.DiskUsedMB, st.DiskTotalMB, st.DiskAvailMB = readDisk("/")
	return st
}

// CPU

func readCPUModel() string {
	f, err := os.Open("/proc/cpuinfo")
	if err != nil {
		return "Unknown CPU"
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(line, "model name") {
			if _, v, ok := strings.Cut(line, ":"); ok {
				return strings.TrimSpace(v)
			}
		}
	}
	return "Unknown CPU"
}

// parseStat parses /proc/stat into per-line cpuTimes
func parseStat() map[string]cpuTimes {
	out := map[string]cpuTimes{}
	f, err := os.Open("/proc/stat")
	if err != nil {
		return out
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) < 6 || !strings.HasPrefix(fields[0], "cpu") {
			continue
		}
		var total, idle uint64
		for i := 1; i < len(fields); i++ {
			n, _ := strconv.ParseUint(fields[i], 10, 64)
			total += n
			if i == 4 || i == 5 { // idle + iowait
				idle += n
			}
		}
		out[fields[0]] = cpuTimes{idle: idle, total: total}
	}
	return out
}

// cpu computes overall and per-core usage from the delta since the last reading.
func (s *Service) cpu() (int, []Core) {
	prev := s.prev
	cur := parseStat()

	overall := 0
	var cores []Core
	// stable order: cpu, cpu0, cpu1, ... so core indices line up with /proc/stat.
	names := make([]string, 0, len(cur))
	for name := range cur {
		names = append(names, name)
	}
	sort.Slice(names, func(i, j int) bool { return cpuLess(names[i], names[j]) })

	for _, name := range names {
		pct := usage(prev[name], cur[name])
		if name == "cpu" {
			overall = pct
			continue
		}
		idx, _ := strconv.Atoi(strings.TrimPrefix(name, "cpu"))
		cores = append(cores, Core{Index: idx, Pct: pct, Freq: coreFreq(name)})
	}
	s.prev = cur
	return overall, cores
}

func usage(prev, cur cpuTimes) int {
	dt := int64(cur.total) - int64(prev.total)
	di := int64(cur.idle) - int64(prev.idle)
	if dt <= 0 {
		return 0
	}
	pct := int(100 * (dt - di) / dt)
	if pct < 0 {
		return 0
	}
	if pct > 100 {
		return 100
	}
	return pct
}

func coreFreq(name string) int {
	b, err := os.ReadFile("/sys/devices/system/cpu/" + name + "/cpufreq/scaling_cur_freq")
	if err != nil {
		return 0
	}
	khz, _ := strconv.Atoi(strings.TrimSpace(string(b)))
	return khz / 1000
}

// cpuLess orders "cpu" first, then cpuN numerically.
func cpuLess(a, b string) bool {
	if a == "cpu" {
		return b != "cpu"
	}
	if b == "cpu" {
		return false
	}
	ai, _ := strconv.Atoi(strings.TrimPrefix(a, "cpu"))
	bi, _ := strconv.Atoi(strings.TrimPrefix(b, "cpu"))
	return ai < bi
}

// Memory

// readMem reproduces what `free` (procps-ng 4.x) reports:
// used = total - available
// buff/cache = Buffers + Cached + SReclaimable; available = MemAvailable
func readMem() (pct, usedMB, totalMB, buffMB, availMB int) {
	m := map[string]uint64{}
	f, err := os.Open("/proc/meminfo")
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		key, val, ok := strings.Cut(sc.Text(), ":")
		if !ok {
			continue
		}
		fields := strings.Fields(val)
		if len(fields) == 0 {
			continue
		}
		n, _ := strconv.ParseUint(fields[0], 10, 64) // kB
		m[key] = n
	}
	total := m["MemTotal"]
	buffcache := m["Buffers"] + m["Cached"] + m["SReclaimable"]
	avail := m["MemAvailable"]
	used := int64(total) - int64(avail)
	if used < 0 {
		used = 0
	}
	if total == 0 {
		return
	}
	pct = int(used * 100 / int64(total))
	return pct, kbToMB(uint64(used)), kbToMB(total), kbToMB(buffcache), kbToMB(avail)
}

func kbToMB(kb uint64) int { return int(kb / 1024) }

// Disk

// readDisk reproduces `df` columns for a mount: total/used/available bytes and the
// rounded-up use percentage.
func readDisk(path string) (pct, usedMB, totalMB, availMB int) {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err != nil {
		return
	}
	bs := uint64(st.Bsize)
	total := st.Blocks * bs
	used := (st.Blocks - st.Bfree) * bs
	avail := st.Bavail * bs
	if denom := used + avail; denom > 0 {
		pct = int((used*100 + denom - 1) / denom) // round up, like df
	}
	return pct, bytesToMB(used), bytesToMB(total), bytesToMB(avail)
}

func bytesToMB(b uint64) int { return int(b / (1024 * 1024)) }

// Temperature

var tempTypes = map[string]bool{
	"x86_pkg_temp": true, "acpitz": true, "cpu_thermal": true, "k10temp": true,
}

func readTemp() int {
	zones, _ := filepath.Glob("/sys/class/thermal/thermal_zone*")
	sort.Strings(zones)
	for _, z := range zones {
		t, err := os.ReadFile(filepath.Join(z, "type"))
		if err != nil || !tempTypes[strings.TrimSpace(string(t))] {
			continue
		}
		if c := readMilliC(filepath.Join(z, "temp")); c > 0 {
			return c
		}
	}
	return readMilliC("/sys/class/thermal/thermal_zone0/temp")
}

func readMilliC(path string) int {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	v, _ := strconv.Atoi(strings.TrimSpace(string(b)))
	return v / 1000
}
