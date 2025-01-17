//go:build !linux && !windows && !freebsd && !solaris && !darwin
// +build !linux,!windows,!freebsd,!solaris,!darwin

package graphdriver

var (
	// Slice of drivers that should be used in an order
	Priority = []string{
		"unsupported",
	}
)

// GetFSMagic returns the filesystem id given the path.
func GetFSMagic(rootpath string) (FsMagic, error) {
	return FsMagicUnsupported, nil
}
