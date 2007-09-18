examples/README.txt

	This directory contains examples how the rendered pages look like
	when invoked with various options.

	The result of 3 pages here are from test run:

		t2html.pl --test-page

	The output from the above command is:

	Run cmd       : perl bin/perl/my/t2html.pl --css-font-normal --Out tmp/t2html.pl-1.txt
	Original text : tmp/t2html.pl-1.txt
	Generated html: tmp/t2html.pl-1.html

	Run cmd       : perl bin/perl/my/t2html.pl --css-font-readable --Out tmp/t2html.pl-2.txt
	Original text : tmp/t2html.pl-2.txt
	Generated html: tmp/t2html.pl-2.html

	Run cmd       : perl bin/perl/my/t2html.pl --html-frame --base tmp/t2html.pl-3.txt --print-url --Out tmp/t2html.pl-3.txt
	Base may need trailing slash: file:tmp/t2html.pl-3.txt at bin/perl/my/t2html.pl line 922.
	Original text : tmp/t2html.pl-3.txt
	Generated html: /tmp/t2html.pl-3.html

End of file
