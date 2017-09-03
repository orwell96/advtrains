tarball: clean
	which zip && zip -r advtrains.zip . -x "assets*" -x "*.zip" -x "*.git*"
clean:
	rm -f advtrains.zip
