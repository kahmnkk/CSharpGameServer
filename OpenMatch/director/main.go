package main

import (
	"context"
	"fmt"
	"io"
	"math/rand"
	"os"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"open-match.dev/open-match/pkg/pb"
)

const (
	omBackendEndpoint         = "open-match-backend.open-match.svc.cluster.local:50505"
	functionHostName          = "open-match-mmf.open-match.svc.cluster.local"
	functionPort        int32 = 50502
	maxConcurrentAssign       = 100
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

	// Connect to Open Match Backend.
	omConn, err := grpc.NewClient(omBackendEndpoint, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect to Open Match Backend, got %s", err.Error())
	}

	defer omConn.Close()
	be := pb.NewBackendServiceClient(omConn)

	// Generate the profiles to fetch matches for.
	profiles := generateProfiles()
	log.Infof("Fetching matches for %v profiles", len(profiles))

	matchesToAssign := make(chan *pb.Match, 30000)

	for i := 0; i < maxConcurrentAssign; i++ {
		go assign(be, matchesToAssign)
	}

	for range time.Tick(time.Second * 5) {
		// Fetch matches for each profile and make random assignments for Tickets in
		// the matches returned.
		var wg sync.WaitGroup
		for _, p := range profiles {
			wg.Add(1)
			go func(wg *sync.WaitGroup, p *pb.MatchProfile) {
				defer wg.Done()
				fetch(be, p, matchesToAssign)
			}(&wg, p)
		}

		// Wait for all profiles to complete before proceeding.
		wg.Wait()
	}
}

func fetch(be pb.BackendServiceClient, p *pb.MatchProfile, matchesToAssign chan<- *pb.Match) {
	req := &pb.FetchMatchesRequest{
		Config: &pb.FunctionConfig{
			Host: functionHostName,
			Port: functionPort,
			Type: pb.FunctionConfig_GRPC,
		},
		Profile: p,
	}

	stream, err := be.FetchMatches(context.Background(), req)
	if err != nil {
		log.Errorf("Failed to fetch matches for profile %v, got %v", p.GetName(), err)
		return
	}

	for {
		resp, err := stream.Recv()
		if err == io.EOF {
			log.Debugf("Finished receiving match stream")
			return
		}

		if err != nil {
			log.Errorf("Failed to get matches from stream, got %v", err)
			return
		}

		log.Infof("Match fetched for profile %v", p.GetName())

		matchesToAssign <- resp.GetMatch()
	}
}

func assign(be pb.BackendServiceClient, matchesToAssign <-chan *pb.Match) {
	for match := range matchesToAssign {
		if match == nil {
			log.Debugf("Received nil match, skipping")
			continue
		}

		log.Debugf("Generated match for profile %s", match.MatchProfile)

		ticketIDs := []string{}
		for _, t := range match.GetTickets() {
			ticketIDs = append(ticketIDs, t.Id)
		}

		// TODO add Agones allocation logic here.

		conn := fmt.Sprintf("%d.%d.%d.%d:2222", rand.Intn(256), rand.Intn(256), rand.Intn(256), rand.Intn(256))
		req := &pb.AssignTicketsRequest{
			Assignments: []*pb.AssignmentGroup{
				{
					TicketIds: ticketIDs,
					Assignment: &pb.Assignment{
						Connection: conn,
					},
				},
			},
		}

		if _, err := be.AssignTickets(context.Background(), req); err != nil {
			log.Errorf("AssignTickets failed for match %v, got %v", match.GetMatchId(), err)
			return
		}

		log.Infof("Assigned server %v to match %v", conn, match.GetMatchId())
	}
}
