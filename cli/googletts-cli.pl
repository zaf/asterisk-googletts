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

my %options;
my @text;
my @filelist;
my $lang    = "en";
my $tmpdir  = "/tmp";
my $timeout = 10;
my $url     = "http://translate.google.com/translate_tts";
my $mpg123  = `/usr/bin/which mpg123`;

VERSION_MESSAGE() if (!@ARGV);

getopts('o:l:t:hqs', \%options);

# Dislpay help messages #
VERSION_MESSAGE() if (defined $options{h});
lang_list("dislpay") if (defined $options{s});

if (!defined $options{t}) {
	say_msg("No text passed for synthesis. Aborting.");
	exit 1;
}

if (!$mpg123) {
	say_msg("mpg123 is missing. Aborting.");
	exit 1;
}
chomp($mpg123);

if (defined $options{l}) {
# check if language setting is valid #
	my %lang_list = lang_list("list");
	if (grep { $_ eq $options{l} } values %lang_list) {
		$lang = $options{l};
	} else {
		say_msg("Invalid language setting. Aborting.");
		exit 1;
	}
}

for ($options{t}) {
# Split input to comply with google tts requirements #
	s/[\\|*~<>^\(\)\[\]\{\}[:cntrl:]]/ /g;
	s/\s+/ /g;
	s/^\s|\s$//g;
	if (!length) {
		say_msg("No text passed for synthesis.");
		exit 1;
	}
	$_ .= "." unless (/^.+[.,?!:;]$/);
	@text = /.{1,100}[.,?!:;]|.{1,100}\s/g;
}

my $ua = LWP::UserAgent->new;
$ua->agent("Mozilla/5.0 (X11; Linux; rv:8.0) Gecko/20100101");
$ua->timeout($timeout);

foreach my $line (@text) {
# Get speech data from google and save them in temp files #
	$line =~ s/^\s+|\s+$//g;
	last if (length($line) == 0);
	$line = escape($line);
	my $request = HTTP::Request->new('GET' => "$url?tl=$lang&q=$line");
	my $response = $ua->request($request);
	if (!$response->is_success) {
		say_msg("Failed to fetch speech data.");
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
# Play speech data back to the user #
	if (system($mpg123, "-q", "-w", $options{o}, @filelist)) {
		say_msg("Failed to playback speech data.");
		exit 1;
	}
} else {
# Save speech data as wav file #
	if (system($mpg123, "-q", @filelist)) {
		say_msg("Failed to write sound file.");
		exit 1;
	}
}

exit 0;

sub say_msg {
# Print messages to user if 'quiet' flag is not set #
	my $message = shift;
	print "$message\n" if (!defined $options{q});
	return;
}

sub VERSION_MESSAGE {
# Help message #
	print "Text to speech synthesis using google voice.\n\n",
		 "Usage: $0 [options] -t [text]\n\n",
		 "Supported options:\n",
		 " -l <lang>      specify the language to use, defaults to 'en' (English)\n",
		 " -o <filename>  write output as WAV file\n",
		 " -q             quiet (Don't print any messages or warnings)\n",
		 " -h             this help message\n",
		 " -s             suppoted languages list\n\n",
		 "Examples:\n",
		 "$0 -l en -t \"Hello world\"\n Have the synthesized speech played back to the user.\n",
		 "$0 -o hello.wav -l en -t \"Hello world\"\n Save the synthesized speech as a wav file.\n\n";
	exit 1;
}

sub lang_list {
# Display the list of supported languages to the user or return it as a hash #
	my $opt = shift;
	my %sup_lang = ("Afrikaans", "af", "Albanian", "sq", "Amharic", "am", "Arabic", "ar",
		"Armenian", "hy", "Azerbaijani", "az", "Basque", "eu", "Belarusian", "be", "Bengali", "bn",
		"Bihari", "bh", "Bosnian", "bs", "Breton", "br", "Bulgarian", "bg", "Cambodian", "km",
		"Catalan", "ca", "Chinese (Simplified)", "zh-CN", "Chinese (Traditional)", "zh-TW",
		"Corsican", "co", "Croatian", "hr", "Czech", "cs", "Danish", "da", "Dutch", "nl",
		"English", "en", "Esperanto", "eo", "Estonian", "et", "Faroese", "fo", "Filipino", "tl",
		"Finnish", "fi", "French", "fr", "Frisian", "fy", "Galician", "gl", "Georgian", "ka",
		"German", "de", "Greek", "el", "Guarani", "gn", "Gujarati", "gu", "Hacker", "xx-hacker",
		"Hausa", "ha", "Hebrew", "iw", "Hindi", "hi", "Hungarian", "hu", "Icelandic", "is",
		"Indonesian", "id", "Interlingua", "ia", "Irish", "ga", "Italian", "it", "Japanese", "ja",
		"Javanese", "jw", "Kannada", "kn", "Kazakh", "kk", "Kinyarwanda", "rw", "Kirundi", "rn",
		"Klingon", "xx-klingon", "Korean", "ko", "Kurdish", "ku", "Kyrgyz", "ky", "Laothian", "lo",
		"Latin", "la", "Latvian", "lv", "Lingala", "ln", "Lithuanian", "lt", "Macedonian", "mk",
		"Malagasy", "mg", "Malay", "ms", "Malayalam", "ml", "Maltese", "mt", "Maori", "mi",
		"Marathi", "mr", "Moldavian", "mo", "Mongolian", "mn", "Montenegrin", "sr-ME", "Nepali", "ne",
		"Norwegian", "no", "Norwegian (Nynorsk)", "nn", "Occitan", "oc", "Oriya", "or", "Oromo", "om",
		"Pashto", "ps", "Persian", "fa", "Pirate", "xx-pirate", "Polish", "pl", "Portuguese (Brazil)", "pt-BR",
		"Portuguese (Portugal)", "pt-PT", "Portuguese", "pt", "Punjabi", "pa", "Quechua", "qu", "Romanian", "ro",
		"Romansh", "rm", "Russian", "ru", "Scots Gaelic", "gd", "Serbian", "sr", "Serbo-Croatian", "sh",
		"Sesotho", "st", "Shona", "sn", "Sindhi", "sd", "Sinhalese", "si", "Slovak", "sk",
		"Slovenian", "sl", "Somali", "so", "Spanish", "es", "Sundanese", "su", "Swahili", "sw",
		"Swedish", "sv", "Tajik", "tg", "Tamil", "ta", "Tatar", "tt", "Telugu", "te", "Thai", "th",
		"Tigrinya", "ti", "Tonga", "to", "Turkish", "tr", "Turkmen", "tk", "Twi", "tw", "Uighur", "ug",
		"Ukrainian", "uk", "Urdu", "ur", "Uzbek", "uz", "Vietnamese", "vi", "Welsh", "cy",
		"Xhosa", "xh", "Yiddish", "yi", "Yoruba", "yo", "Zulu", "zu");

	if ($opt eq "dislpay") {
		print "Supported Languages list:\n";
		printf("%-22s:  %s\n", $_, $sup_lang{$_}) foreach (sort keys %sup_lang);
		exit 1;
	} elsif ($opt eq "list") {
		return %sup_lang;
	}
}
