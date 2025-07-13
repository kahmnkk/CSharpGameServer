package main

import (
	"open-match.dev/open-match/pkg/pb"
)

// generateProfiles generates match profiles
func generateProfiles() []*pb.MatchProfile {
	var profiles []*pb.MatchProfile
	modes := []string{"mode.random"}
	for _, mode := range modes {
		profiles = append(profiles, &pb.MatchProfile{
			Name: "match_" + mode,
			Pools: []*pb.Pool{
				{
					Name: "pool_" + mode,
					TagPresentFilters: []*pb.TagPresentFilter{
						{
							Tag: mode,
						},
					},
				},
			},
		},
		)
	}

	return profiles
}
