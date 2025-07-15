package mmf

import (
	"fmt"

	"github.com/rs/xid"
	log "github.com/sirupsen/logrus"

	"open-match.dev/open-match/pkg/matchfunction"
	"open-match.dev/open-match/pkg/pb"
)

const (
	ticketsPerPoolPerMatch = 2

	MATCH_RANDOM = "match.random"
	MATCH_CODE   = "match.code"
)

// Run is this match function's implementation of the gRPC call defined in api/matchfunction.proto.
func (s *MatchFunctionService) Run(req *pb.RunRequest, stream pb.MatchFunction_RunServer) error {
	// Fetch tickets for the pools specified in the Match Profile.
	poolTickets, err := matchfunction.QueryPools(stream.Context(), s.queryServiceClient, req.GetProfile().GetPools())
	if err != nil {
		log.Errorf("Failed to query tickets for the given pools, got %s", err.Error())
		return err
	}

	// Generate proposals.
	proposals, err := makeMatches(req.GetProfile(), poolTickets)
	if err != nil {
		log.Errorf("Failed to generate matches, got %s", err.Error())
		return err
	}

	// Stream the generated proposals back to Open Match.
	for _, proposal := range proposals {
		log.Infof("Streaming %v proposals to Open Match for function %v", len(proposals), req.GetProfile().GetName())
		if err := stream.Send(&pb.RunResponse{Proposal: proposal}); err != nil {
			log.Printf("Failed to stream proposals to Open Match, got %s", err.Error())
			return err
		}
	}

	return nil
}

func makeMatches(p *pb.MatchProfile, poolTickets map[string][]*pb.Ticket) ([]*pb.Match, error) {
	switch p.GetName() {
	case MATCH_RANDOM:
		return makeRandomMatches(p, poolTickets)
	case MATCH_CODE:
		return makeCodeMatches(p, poolTickets)
	default:
		log.Errorf("Unknown match profile %v", p.GetName())
		return nil, fmt.Errorf("unknown match profile %v", p.GetName())
	}
}

func makeRandomMatches(p *pb.MatchProfile, poolTickets map[string][]*pb.Ticket) ([]*pb.Match, error) {
	var matches []*pb.Match
	count := 0

	for {
		insufficientTickets := false
		matchTickets := []*pb.Ticket{}
		for pool, tickets := range poolTickets {
			if len(tickets) < ticketsPerPoolPerMatch {
				// This pool is completely drained out. Stop creating matches.
				insufficientTickets = true
				break
			}

			// Remove the Tickets from this pool and add to the match proposal.
			matchTickets = append(matchTickets, tickets[0:ticketsPerPoolPerMatch]...)
			poolTickets[pool] = tickets[ticketsPerPoolPerMatch:]
		}

		if insufficientTickets {
			break
		}

		matches = append(matches, &pb.Match{
			MatchId:       fmt.Sprintf("%v-%v-%v", p.GetName(), xid.New().String(), count),
			MatchProfile:  p.GetName(),
			MatchFunction: "match",
			Tickets:       matchTickets,
		})

		count++
	}

	return matches, nil
}

// makeCodeMatches 티켓에 포함되어 있는 "code" 검색 필드를 기준으로 매치를 생성합니다. (친선경기)
func makeCodeMatches(p *pb.MatchProfile, poolTickets map[string][]*pb.Ticket) ([]*pb.Match, error) {
	var matches []*pb.Match
	count := 0

	// code별로 티켓을 그룹화합니다.
	poolsByCode := make(map[string][]*pb.Ticket)
	for _, tickets := range poolTickets {
		for _, ticket := range tickets {
			code := ticket.GetSearchFields().StringArgs["code"]
			poolsByCode[code] = append(poolsByCode[code], ticket)
		}
	}

	for _, tickets := range poolsByCode {
		if len(tickets) < ticketsPerPoolPerMatch {
			continue
		}

		matchTickets := tickets[0:ticketsPerPoolPerMatch]

		mId := fmt.Sprintf("%v-%v-%v", p.GetName(), xid.New().String(), count)
		matches = append(matches, &pb.Match{
			MatchId:       mId,
			MatchProfile:  p.GetName(),
			MatchFunction: "match",
			Tickets:       matchTickets,
		})

		log.Debugf("Created match %s with tickets %v", mId, matchTickets)

		count++
	}

	return matches, nil
}
