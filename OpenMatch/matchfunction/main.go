package main

import (
	"os"

	"github.com/kyuhh1214/CSharpServer/MatchMaker/matchfunction/mmf"
	log "github.com/sirupsen/logrus"
)

// This tutorial implenents a basic Match Function that is hosted in the below
// configured port. You can also configure the Open Match QueryService endpoint
// with which the Match Function communicates to query the Tickets.

const (
	queryServiceAddress = "open-match-query.open-match.svc.cluster.local:50503" // Address of the QueryService endpoint.
	serverPort          = 50502                                                 // The port for hosting the Match Function.
)

func getLogLevel() log.Level {
	switch os.Getenv("LOG_LEVEL") {
	case "trace":
		return log.TraceLevel
	case "debug":
		return log.DebugLevel
	case "info":
		return log.InfoLevel
	case "warn":
		return log.WarnLevel
	case "error":
		return log.ErrorLevel
	}

	return log.InfoLevel
}

func main() {
	log.SetLevel(getLogLevel())
	log.SetFormatter(&log.TextFormatter{
		FullTimestamp: true,
	})

	mmf.Start(queryServiceAddress, serverPort)
}
