stage2.lsp: $(wildcard stage2/*.lsp)
	# strip comments
	sed -E '/^ *(;.*)?$$/d' $^ > stage2.lsp

clean-stage2:
	rm -f stage2.lsp

.PHONY: clean-stage2
