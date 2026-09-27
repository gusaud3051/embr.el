EMACS ?= emacs
PYTHON ?= python3
SHELLCHECK ?= shellcheck

test: checkparens bytecompile checkpy shellcheck ert

check: test

checkparens:
	$(EMACS) --batch --eval '(find-file "embr.el")' --eval '(check-parens)' && echo "OK: embr.el parens balanced"
	$(EMACS) --batch --eval '(find-file "embr-passwd.el")' --eval '(check-parens)' && echo "OK: embr-passwd.el parens balanced"

bytecompile:
	$(EMACS) --batch -L . -f batch-byte-compile embr.el && rm -f embr.elc && echo "OK: embr.el byte-compiles cleanly"
	$(EMACS) --batch -L . -f batch-byte-compile embr-passwd.el && rm -f embr-passwd.elc && echo "OK: embr-passwd.el byte-compiles cleanly"

checkpy:
	$(PYTHON) -m py_compile embr.py && echo "OK: embr.py syntax valid"
	$(PYTHON) -m py_compile tools/embr-perf-report.py && echo "OK: embr-perf-report.py syntax valid"

shellcheck:
	$(SHELLCHECK) setup.sh && echo "OK: shell scripts pass shellcheck"

ert:
	$(EMACS) -Q --batch -L . -l tests/embr-canvas-tests.el --eval '(ert-run-tests-batch-and-exit (quote (not (tag native))))'

# Native canvas module — requires Emacs 32 or patched Emacs 31 + libjpeg-turbo.
module:
	$(MAKE) -C native EMACS="$(EMACS)"

# Run in a separate GUI Emacs: canvas buffers require a graphical frame.
test-canvas: module
	$(EMACS) -Q -l "$(CURDIR)/tests/run-canvas-tests.el"

.PHONY: test check checkparens bytecompile checkpy shellcheck ert module test-canvas
