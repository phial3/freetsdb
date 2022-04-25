package run_test

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/freetsdb/freetsdb/cmd/freetsd_meta/run"
)

func TestCommand_PIDFile(t *testing.T) {
	tmpdir, err := ioutil.TempDir(os.TempDir(), "freetsd-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpdir)

	pidFile := filepath.Join(tmpdir, "freetsdb.pid")

	// Override the default data/wal dir so it doesn't look in ~/.freetsdb which
	// might have junk not related to this test.
	os.Setenv("FREETSDB_DATA_DIR", tmpdir)
	os.Setenv("FREETSDB_DATA_WAL_DIR", tmpdir)

	cmd := run.NewCommand()
	// cmd.Getenv = func(key string) string {
	// 	switch key {
	// 	case "FREETSDB_DATA_DIR":
	// 		return filepath.Join(tmpdir, "data")
	// 	case "FREETSDB_META_DIR":
	// 		return filepath.Join(tmpdir, "meta")
	// 	case "FREETSDB_DATA_WAL_DIR":
	// 		return filepath.Join(tmpdir, "wal")
	// 	case "FREETSDB_BIND_ADDRESS", "FREETSDB_HTTP_BIND_ADDRESS":
	// 		return "127.0.0.1:0"
	// 	case "FREETSDB_REPORTING_DISABLED":
	// 		return "true"
	// 	default:
	// 		return os.Getenv(key)
	// 	}
	// }

	if err := cmd.Run("-pidfile", pidFile, "-config", os.DevNull); err != nil {
		t.Fatalf("unexpected error: %s", err)
	}

	if _, err := os.Stat(pidFile); err != nil {
		t.Fatalf("could not stat pid file: %s", err)
	}
	go cmd.Close()

	timeout := time.NewTimer(100 * time.Millisecond)
	select {
	case <-timeout.C:
		t.Fatal("unexpected timeout")
	case <-cmd.Closed:
		timeout.Stop()
	}

	if _, err := os.Stat(pidFile); err == nil {
		t.Fatal("expected pid file to be removed")
	}
}
