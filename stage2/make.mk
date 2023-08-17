stage2.lsp: $(wildcard stage2/*.lsp)
	# strip comments
	sed -E '/^ *(;.*)?$$/d' $^ > stage2.lsp
	[[ "${SHUTDOWN}" == 1 ]] && echo "(call-native shutdown$$ 0)" >> stage2.lsp || true

clean-stage2:
	rm -f stage2.lsp

.PHONY: clean-stage2
