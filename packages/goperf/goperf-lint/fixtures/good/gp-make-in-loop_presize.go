package good

func fill(n int) []byte {
	b := make([]byte, 0, n*64)
	for i := 0; i < n; i++ {
		b = append(b, byte(i))
	}
	return b
}
