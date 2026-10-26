package good

import "os"

func openMany(paths []string) error {
	for _, p := range paths {
		f, err := os.Open(p)
		if err != nil {
			return err
		}
		_, _ = f.Stat()
		_ = f.Close()
	}
	return nil
}
