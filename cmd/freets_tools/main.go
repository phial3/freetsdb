// The freets_tools command displays detailed information about FreeTSDB data files.
package main

import (
	"errors"
	"fmt"
	"io"
	"os"

	"github.com/freetsdb/freetsdb/cmd"
	"github.com/freetsdb/freetsdb/cmd/freets_tools/compact"
	"github.com/freetsdb/freetsdb/cmd/freets_tools/export"
	"github.com/freetsdb/freetsdb/cmd/freets_tools/help"
	"github.com/freetsdb/freetsdb/cmd/freets_tools/importer"
	"github.com/freetsdb/freetsdb/cmd/freets_tools/server"
	dataRun "github.com/freetsdb/freetsdb/cmd/freetsd/run"
	metaRun "github.com/freetsdb/freetsdb/cmd/freetsd_meta/run"
	"github.com/freetsdb/freetsdb/services/meta"
	"github.com/freetsdb/freetsdb/tsdb"
	_ "github.com/freetsdb/freetsdb/tsdb/engine"
	"go.uber.org/zap"
)

func main() {
	m := NewMain()
	if err := m.Run(os.Args[1:]...); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

// Main represents the program execution.
type Main struct {
	Stdin  io.Reader
	Stdout io.Writer
	Stderr io.Writer
}

// NewMain returns a new instance of Main.
func NewMain() *Main {
	return &Main{
		Stdin:  os.Stdin,
		Stdout: os.Stdout,
		Stderr: os.Stderr,
	}
}

// Run determines and runs the command specified by the CLI args.
func (m *Main) Run(args ...string) error {
	name, args := cmd.ParseCommandName(args)

	// Extract name from args.
	switch name {
	case "", "help":
		if err := help.NewCommand().Run(args...); err != nil {
			return fmt.Errorf("help failed: %s", err)
		}
	case "compact-shard":
		c := compact.NewCommand()
		if err := c.Run(args); err != nil {
			return fmt.Errorf("compact-shard failed: %s", err)
		}
	case "export":
		c := export.NewCommand(&ossServer{logger: zap.NewNop()})
		if err := c.Run(args); err != nil {
			return fmt.Errorf("export failed: %s", err)
		}
	case "import":
		cmd := importer.NewCommand(&ossServer{logger: zap.NewNop()})
		if err := cmd.Run(args); err != nil {
			return fmt.Errorf("import failed: %s", err)
		}
	default:
		return fmt.Errorf(`unknown command "%s"`+"\n"+`Run 'freets-tools help' for usage`+"\n\n", name)
	}

	return nil
}

type ossServer struct {
	logger     *zap.Logger
	config     *dataRun.Config
	metaConfig *metaRun.Config
	noClient   bool
	client     *meta.Client
}

func (s *ossServer) Open(path string) (err error) {
	s.config, err = s.parseConfig(path)
	if err != nil {
		return err
	}

	// Validate the configuration.
	if err = s.config.Validate(); err != nil {
		return fmt.Errorf("validate config: %s", err)
	}

	if s.noClient {
		return nil
	}

	s.client = meta.NewClient(nil)
	if err = s.client.Open(); err != nil {
		s.client = nil
		return err
	}
	return nil
}

func (s *ossServer) Close() {
	if s.client != nil {
		s.client.Close()
		s.client = nil
	}
}

func (s *ossServer) MetaClient() server.MetaClient { return s.client }
func (s *ossServer) TSDBConfig() tsdb.Config       { return s.config.Data }
func (s *ossServer) Logger() *zap.Logger           { return s.logger }

// ParseConfig parses the config at path.
// It returns a demo configuration if path is blank.
func (s *ossServer) parseConfig(path string) (*dataRun.Config, error) {
	path = s.resolvePath(path)
	// Use demo configuration if no config path is specified.
	if path == "" {
		return nil, errors.New("missing config file")
	}

	config := dataRun.NewConfig()
	if err := config.FromTomlFile(path); err != nil {
		return nil, err
	}

	return config, nil
}

func (s *ossServer) resolvePath(path string) string {
	if path != "" {
		if path == os.DevNull {
			return ""
		}
		return path
	}

	for _, p := range []string{
		os.ExpandEnv("${HOME}/.freetsdb/freetsdb.conf"),
		"/etc/freetsdb/freetsdb.conf",
	} {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}
