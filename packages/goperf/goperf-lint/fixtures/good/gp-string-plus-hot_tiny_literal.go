//go:build ignore

package good

func cidr(ips []string) []string {
	out := make([]string, 0, len(ips))
	for _, ip := range ips {
		trusted := ip
		trusted += "/32"
		out = append(out, trusted)
	}
	return out
}
