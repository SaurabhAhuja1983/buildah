package graphdriver

var (
	// Slice of drivers that should be used in order
	Priority = []string{
		"vfs",
	}
)

// GetFSMagic returns the filesystem id given the path.
func GetFSMagic(rootpath string) (FsMagic, error) {
	// Note it is OK to return FsMagicUnsupported on Windows.
	return FsMagicUnsupported, nil
}
