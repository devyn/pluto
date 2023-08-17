stage2.lsp: $(wildcard stage2/*.lsp)
	# strip comments
	sed -E '/^ *(;.*)?$$/d' $^ > stage2.lsp
	if [[ "${SHUTDOWN}" == 1 ]]; then \
		echo "(call-native shutdown\\$$ 0)" >> stage2.lsp \
	fi

clean-stage2:
	rm -f stage2.lsp

.PHONY: clean-stage2
