#!/usr/bin/env perl

#
# Script that uses Google Translate for text to speech synthesis.
#
# Copyright (C) 2012, Lefteris Zafiris <zaf.000@gmail.com>
#
# This program is free software, distributed under the terms of
# the GNU General Public License Version 2.
#

use warnings;
use strict;
use File::Temp qw(tempfile);
use CGI::Util qw(escape);
use LWP::UserAgent;

my @text;
my $lang;
my @filelist;
my $tmpdir = "/tmp";
my $url    = "http://translate.google.com/translate_tts";
my $mpg123 = `/usr/bin/which mpg123`;

if (!@ARGV || $ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
	print "Text to speech synthesis using google voice.\n\n";
	print "Usage  : $0 [Language] [Text]\n";
	print "Example: $0 en \"hello world\"\n\n";
	exit;
}

die "mpg123 is missing. Aborting.\n" if (!$mpg123);
chomp($mpg123);

if ($ARGV[0] =~ /^[a-z]{2}(-[a-zA-Z]{2,6})?$/) {
	$lang = $ARGV[0];
} else {
	die "Wrong language setting. Aborting.\n";
}

for ($ARGV[1]) {
	s/[\\|*~<>^\(\)\[\]\{\}[:cntrl:]]/ /g;
	s/\s+/ /g;
	s/^\s|\s$//g;
	die "No text passed for synthesis.\n" if (!length);
	$_ .= "." unless (/^.+[.,?!:;]$/);
	@text = /.{1,100}[.,?!:;]|.{1,100}\s/g;
}

my $ua = LWP::UserAgent->new;
$ua->agent("Mozilla/5.0 (X11; Linux; rv:8.0) Gecko/20100101");
$ua->timeout(10);

foreach my $line (@text) {
	$line =~ s/^\s+|\s+$//g;
	last if (length($line) == 0);
	$line = escape($line);
	my $request = HTTP::Request->new('GET' => "$url?tl=$lang&q=$line");
	my $response = $ua->request($request);
	if (!$response->is_success) {
		die "Failed to fetch speech data.\n";
	} else {
		my ($fh, $tmpname) = tempfile(
			"tts_XXXXXX",
			SUFFIX => ".mp3",
			DIR    => $tmpdir,
			UNLINK => 1,
		);
		open($fh, ">", "$tmpname") or die "Unable to open file: $!";
		print $fh $response->content;
		close $fh;
		push(@filelist, $tmpname);
	}
}
system($mpg123, "-q", @filelist) ==0 or die "Failed to playback speech data.\n";
exit;
