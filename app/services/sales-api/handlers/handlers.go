// Package handlers contains all the full set of handler functions and routes
// supported by the web api
package handlers

import (
	"expvar"
	"net/http"
	"net/http/pprof"
	"os"

	"github.com/ZweWT/go-service/app/services/sales-api/handlers/debug/checkgrp"
	"github.com/ZweWT/go-service/app/services/sales-api/handlers/v1/testgrp"
	"github.com/ZweWT/go-service/foundation/web"
	"go.uber.org/zap"
)

// DebugStandardLibraryMux registers all the debug routes from the standard library
// into a new mux bypassing the use of the DefaultServerMux. Using the
// DefaultServerMux would be a security risk since a dependency could inject a
// handler into the service without us knowing it.
func DebugStandardLibraryMux() *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("/debug/pprof", pprof.Index)
	mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
	mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	mux.HandleFunc("/debug/pprof/trace", pprof.Trace)
	mux.Handle("/debug/vars", expvar.Handler())

	return mux
}

// DebugMux registers all the debug standard library routes and other custom
// debug application routes for the service.
func DebugMux(build string, log *zap.SugaredLogger) http.Handler {
	mux := DebugStandardLibraryMux()

	// Register debug check endpoints.
	cgh := checkgrp.Handlers{
		Build: build,
		Log:   log,
	}

	mux.HandleFunc("/debug/readiness", cgh.Readiness)
	mux.HandleFunc("/debug/liveness", cgh.Liveness)

	return mux
}

type APIMuxConfig struct {
	Shutdown chan os.Signal
	Log      *zap.SugaredLogger
}

func APIMux(cfg APIMuxConfig) *web.App {
	app := web.NewApp(cfg.Shutdown)

	tgh := testgrp.Handlers{
		Log: cfg.Log,
	}

	app.Handle(http.MethodGet, "/v1/test", tgh.Test)

	return app
}
