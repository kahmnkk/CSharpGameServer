package main

import (
	"open-match.dev/open-match/pkg/pb"
)

const (
	MATCH_RANDOM = "random"
	MATCH_CODE   = "code"
)

// generateProfiles generates match profiles
func generateProfiles() []*pb.MatchProfile {
	var profiles []*pb.MatchProfile
	modes := []string{MATCH_RANDOM, MATCH_CODE}
	for _, mode := range modes {
		switch mode {
		case MATCH_RANDOM, MATCH_CODE:
			profiles = append(profiles, &pb.MatchProfile{
				Name: "match." + mode,
				Pools: []*pb.Pool{
					{
						Name:              "pool." + mode,
						TagPresentFilters: []*pb.TagPresentFilter{{Tag: mode}},
					},
				},
			},
			)
		}
	}

	return profiles
}
