package main

import (
	"errors"
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"

	"github.com/ardanlabs/conf/v3"
	"go.uber.org/automaxprocs/maxprocs"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var build = "develop"

func main() {

	fmt.Printf("build: %s", build)
	// construct applicatin logger
	log, err := initLogger("SALES-API")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	defer log.Sync()

	// Perform the startup and shutdown sequence
	if err := run(log); err != nil {
		log.Errorw("start up", "Error", err)
		os.Exit(1)
	}

}

func run(log *zap.SugaredLogger) error {
	// ==========================================================================
	// GOMAXPROCS

	// Set the correct numbers of threads for the service
	// based on what is available either by the machine or quotas
	if _, err := maxprocs.Set(); err != nil {
		return fmt.Errorf("max procs: %w", err)
	}

	log.Infow("start up", "GOMAXPROCS", runtime.GOMAXPROCS(0))

	// ==========================================================================
	// Configuration

	cfg := struct {
		conf.Version
		Web struct {
			APIHost         string        `conf:"default:0.0.0.0:3000"`
			DebugHost       string        `conf:"default:0.0.0.0:4000"`
			ReadTimeout     time.Duration `conf:"default:5s"`
			WriteTimeout    time.Duration `conf:"default:10s"`
			IdleTimeout     time.Duration `conf:"default:120s"`
			ShutdownTimeout time.Duration `conf:"default:20s"`
		}
	}{
		Version: conf.Version{
			Build: build,
			Desc:  "information",
		},
	}

	//prefixing before config variables
	const prefix = "SALES"
	help, err := conf.Parse(prefix, &cfg)
	if err != nil {
		if errors.Is(err, conf.ErrHelpWanted) {
			fmt.Println(help)
			return nil
		}
		return fmt.Errorf("parsing config: %w", err)
	}

	// ==========================================================================
	// App Starting

	log.Infow("starting service", "version", build)
	defer log.Infow("shutdown complete")

	out, err := conf.String(&cfg)
	if err != nil {
		return fmt.Errorf("generating config for output: %w", err)
	}
	log.Infow("startup", "config", out)

	// ==========================================================================
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, syscall.SIGINT, syscall.SIGTERM)
	<-shutdown

	return nil

}

func initLogger(service string) (*zap.SugaredLogger, error) {
	config := zap.NewProductionConfig()
	config.OutputPaths = []string{"stdout"}
	config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	config.DisableStacktrace = true
	config.InitialFields = map[string]interface{}{
		"service": service,
	}

	log, err := config.Build()
	if err != nil {
		return nil, err
	}

	return log.Sugar(), nil
}
