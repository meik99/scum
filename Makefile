.PHONY: package
package:
	cd charts && helm package ../chart
	cd charts && helm repo index .
	git add -A
	git commit -m "feat: update chart"
	git push

