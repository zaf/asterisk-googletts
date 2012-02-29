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
use Getopt::Std;
use File::Temp qw(tempfile);
use CGI::Util qw(escape);
use LWP::UserAgent;

&VERSION_MESSAGE() if (!@ARGV);

my %options;
my @text;
my @filelist;
my $lang    = "en";
my $tmpdir  = "/tmp";
my $url     = "http://translate.google.com/translate_tts";
my $mpg123  = `/usr/bin/which mpg123`;

getopts('o:l:t:hq', \%options);

&VERSION_MESSAGE() if (defined $options{h});
if (!defined $options{t}) {
	&say_msg("No text passed for synthesis. Aborting.");
	exit 1;
}
if (!$mpg123) {
	&say_msg("mpg123 is missing. Aborting.");
	exit 1;
}
chomp($mpg123);

if (defined $options{l}) {
	if ($options{l} =~ /^[a-z]{2}(-[a-zA-Z]{2,6})?$/) {
		$lang = $options{l};
	} else {
		&say_msg("Wrong language setting. Aborting.");
		exit 1;
	}
}

for ($options{t}) {
	s/[\\|*~<>^\(\)\[\]\{\}[:cntrl:]]/ /g;
	s/\s+/ /g;
	s/^\s|\s$//g;
	if (!length) {
		&say_msg("No text passed for synthesis.");
		exit 1;
	}
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
		&say_msg("Failed to fetch speech data.");
		exit 1;
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

if (defined $options{o}) {
	if (system($mpg123, "-q", "-w", $options{o}, @filelist)) {
		&say_msg("Failed to playback speech data.");
		exit 1;
	}
} else {
	if (system($mpg123, "-q", @filelist)) {
		&say_msg("Failed to write sound file.");
		exit 1;
	}
}

exit 0;

sub say_msg {
	print @_, "\n" if (!defined $options{q});
}

sub VERSION_MESSAGE {
	print "Text to speech synthesis using google voice.\n\n",
		 "Usage: $0 [options] -t [text]\n\n",
		 "Supported options:\n",
		 " -l <lang>      specify the language to use, defaults to 'en' (English)\n",
		 " -o <filename>  write output as WAV file\n",
		 " -q             quiet (Don't print any messages or warnings)\n",
		 " -h             this help message\n\n",
		 "Examples:\n",
		 "$0 -l en -t \"Hello world\"\n Have the synthesized speech played back to the user.\n",
		 "$0 -o hello.wav -l en -t \"Hello world\"\n Save the synthesized speech as a wav file.\n";
	exit 1;
}
