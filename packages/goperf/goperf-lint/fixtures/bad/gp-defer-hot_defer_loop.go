package bad

import "os"

func openMany(paths []string) error {
	for _, p := range paths {
		f, err := os.Open(p)
		if err != nil {
			return err
		}
		defer f.Close()
		_ = f
	}
	return nil
}
