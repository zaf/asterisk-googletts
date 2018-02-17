#!/usr/bin/env perl

#
# Script that uses Google Translate for text to speech synthesis.
#
# Copyright (C) 2012 - 2015, Lefteris Zafiris <zaf@fastmail.com>
#
# This program is free software, distributed under the terms of
# the GNU General Public License Version 2.
#

use warnings;
use strict;
use utf8;
use Encode qw(decode encode);
use Getopt::Std;
use File::Temp qw(tempfile);
use URI::Escape;
use HTTP::Tiny;

my %options;
my @text;
my @mp3list;
my $samplerate;
my $input;
my $speed   = 1;
my $lang    = "en";
my $tmpdir  = "/tmp";
my $timeout = 10;
my $url     = "https://translate.google.com";
my $mpg123  = `/usr/bin/which mpg123`;
my $sox     = `/usr/bin/which sox`;

VERSION_MESSAGE() if (!@ARGV);

getopts('o:l:r:t:f:s:hqv', \%options);

# Dislpay help messages #
VERSION_MESSAGE() if (defined $options{h});
lang_list("dislpay") if (defined $options{v});

if (!$mpg123 || !$sox) {
	say_msg("mpg123 or sox is missing. Aborting.");
	exit 1;
}
chomp($mpg123, $sox);

parse_options();
$input = decode('utf8', $input);
for ($input) {
	# Split input to comply with google tts requirements #
	s/[\\|*~<>^\n\(\)\[\]\{\}[:cntrl:]]/ /g;
	s/\s+/ /g;
	s/^\s|\s$//g;
	if (!length) {
		say_msg("No text passed for synthesis.");
		exit 1;
	}
	@text = /.{1,150}$|.{1,150}[.,?!:;]|.{1,150}\s/g;
}
my $lines = @text;

# Initialise User angent #
my $http = HTTP::Tiny->new(
	agent      => 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:52.0) Gecko/20100101 Firefox/52.0',
	timeout    => $timeout,
	verify_SSL => 1,
);

for (my $i = 0; $i < $lines; $i++) {
	# Get speech data from google and save them in temp files #
	my $len = length($text[$i]);
	my $line = encode('utf8', $text[$i]);
	$line =~ s/^\s+|\s+$//g;
	next if (length($line) == 0);
	my $token = make_token($line);
	$line = uri_escape($line);
	my ($mp3_fh, $mp3_name) = tempfile(
		"tts_XXXXXX",
		DIR    => $tmpdir,
		SUFFIX => ".mp3",
		UNLINK => 1
	);
	my $headers = {
		'Accept'          => '*/*',
		'Accept-Encoding' => 'identity;q=1, *;q=0',
		'Accept-Language' => 'en-US,en;q=0.5',
		'DNT'             => '1',
		'Range'           => 'bytes=0-',
		'Referer'         => 'https://translate.google.com/',
	};
	my $response = $http->mirror(
		"$url/translate_tts?ie=UTF-8&q=$line&tl=$lang&total=$lines&idx=$i&textlen=$len&client=tw-ob&tk=$token&prev=input",
		$mp3_name,
		$headers,
	);

	if (!$response->{success}) {
		say_msg("Failed to fetch speech data: ", $response->{status}, $response->{reason});
		exit 1;
	} else {
		push(@mp3list, $mp3_name);
	}
}

# decode mp3s and concatenate #
my ($wav_fh, $wav_name) = tempfile(
	"tts_XXXXXX",
	DIR    => $tmpdir,
	SUFFIX => ".wav",
	UNLINK => 1
);
if (system($mpg123, "-q", "-w", $wav_name, @mp3list)) {
	say_msg("mpg123 failed to process sound file.");
	exit 1;
}

# Set sox args and process wav file #
my @soxargs = ($sox, "-q", $wav_name);
defined $options{o} ? push(@soxargs, ($options{o})) : push(@soxargs, ("-t", "alsa", "-d"));
push(@soxargs, ("tempo", "-s", $speed)) if ($speed != 1);
push(@soxargs, ("rate", $samplerate)) if ($samplerate);

if (system(@soxargs)) {
	say_msg("sox failed to process sound file.");
	exit 1;
}

exit 0;

sub say_msg {
	# Print messages to user if 'quiet' flag is not set #
	my @message = @_;
	warn @message if (!defined $options{q});
	return;
}

sub parse_options {
	# Get input text #
	if (defined $options{t}) {
		$input = $options{t};
	} elsif (defined $options{f}) {
		if (open(my $fh, "<", "$options{f}")) {
			$input = do { local $/; <$fh> };
			close($fh);
		} else {
			say_msg("Cant read file $options{f}");
			exit 1;
		}
	} else {
		say_msg("No text passed for synthesis.");
		exit 1;
	}

	# set the speech language #
	if (defined $options{l}) {
		$options{l} =~ /^[a-zA-Z]{2}(-[a-zA-Z]{2})?$/ ? $lang = $options{l}
			: say_msg("Invalid language setting, using default.");
	}

	# set audio sample rate #
	if (defined $options{r}) {
		$options{r} =~ /\d+/ ? $samplerate = $options{r}
			: say_msg("Invalid sample rate, using default.");
	}

	# set speed factor #
	if (defined $options{s}) {
		$options{s} =~ /\d+/ ? $speed = $options{s}
			: say_msg("Invalind speed factor, using default.");
	}
	return;
}

# Obfuscated crap straight from Google:
# https://translate.google.com/translate/releases/twsfe_w_20151214_RC03/r/js/desktop_module_main.js
sub make_token {
	my $text = shift;
	my $time = int(time() / 3600);
	my @chars = unpack('U*', $text);
	my $stamp = $time;

	foreach (@chars) {
		$stamp = make_rl($stamp + $_, '+-a^+6');
	}
	$stamp = make_rl($stamp, '+-3^+b+-f');
	if ($stamp < 0) {
		$stamp = ($stamp & 2147483647) + 2147483648;
	}
	$stamp %= 10**6;
	return ($stamp . '.' . ($stamp ^ $time));
}

sub make_rl {
	my ($num, $str) = @_;

	for (my $i = 0; $i < length($str) - 2 ; $i += 3) {
		my $d = substr($str, $i+2, 1);
		if (ord($d) >= ord('a')) {
			$d = ord($d) - 87;
		} else {
			$d = int($d);
		}
		if (substr($str, $i+1, 1) eq '+') {
			$d = $num >> $d;
		} else {
			$d = $num << $d;
		}
		if (substr($str, $i, 1) eq '+') {
			$num = $num + $d & 4294967295;
		} else {
			$num = $num ^ $d;
		}
	}
	return $num;
}

sub VERSION_MESSAGE {
	# Help message #
	print "Text to speech synthesis using google voice.\n\n",
		"Supported options:\n",
		" -t <text>      text string to synthesize\n",
		" -f <file>      text file to synthesize\n",
		" -l <lang>      specify the language to use, defaults to 'en' (English)\n",
		" -o <filename>  write output as WAV file\n",
		" -r <rate>      specify the output sampling rate in Hertz (default 22050)\n",
		" -s <factor>    specify the output speed factor\n",
		" -q             quiet (Don't print any messages or warnings)\n",
		" -h             this help message\n",
		" -v             suppoted languages list\n\n",
		"Examples:\n",
		"$0 -l en -t \"Hello world\"\n Have the synthesized speech played back to the user.\n",
		"$0 -o hello.wav -l en -t \"Hello world\"\n Save the synthesized speech as a wav file.\n\n";
	exit 1;
}

sub lang_list {
	# Display the list of supported languages to the user or return it as a hash #
	my $opt      = shift;
	my %sup_lang = (
		"Afrikaans",            "af",    "Albanian",              "sq",    "Amharic",             "am",
		"Arabic",               "ar",    "Armenian",              "hy",    "Azerbaijani",         "az",
		"Basque",               "eu",    "Belarusian",            "be",    "Bengali",             "bn",
		"Bihari",               "bh",    "Bosnian",               "bs",    "Breton",              "br",
		"Bulgarian",            "bg",    "Cambodian",             "km",    "Catalan",             "ca",
		"Chinese (Simplified)", "zh-CN", "Chinese (Traditional)", "zh-TW", "Corsican",            "co",
		"Croatian",             "hr",    "Czech",                 "cs",    "Danish",              "da",
		"Dutch",                "nl",    "English",               "en",    "Esperanto",           "eo",
		"Estonian",             "et",    "Faroese",               "fo",    "Filipino",            "tl",
		"Finnish",              "fi",    "French",                "fr",    "Frisian",             "fy",
		"Galician",             "gl",    "Georgian",              "ka",    "German",              "de",
		"Greek",                "el",    "Guarani",               "gn",    "Gujarati",            "gu",
		"Hausa",                "ha",    "Hebrew",                "iw",    "Hindi",               "hi",
		"Hungarian",            "hu",    "Icelandic",             "is",    "Indonesian",          "id",
		"Interlingua",          "ia",    "Irish",                 "ga",    "Italian",             "it",
		"Japanese",             "ja",    "Javanese",              "jw",    "Kannada",             "kn",
		"Kazakh",               "kk",    "Kinyarwanda",           "rw",    "Kirundi",             "rn",
		"Korean",               "ko",    "Kurdish",               "ku",    "Kyrgyz",              "ky",
		"Laothian",             "lo",    "Latin",                 "la",    "Latvian",             "lv",
		"Lingala",              "ln",    "Lithuanian",            "lt",    "Macedonian",          "mk",
		"Malagasy",             "mg",    "Malay",                 "ms",    "Malayalam",           "ml",
		"Maltese",              "mt",    "Maori",                 "mi",    "Marathi",             "mr",
		"Moldavian",            "mo",    "Mongolian",             "mn",    "Montenegrin",         "sr-ME",
		"Nepali",               "ne",    "Norwegian",             "no",    "Norwegian (Nynorsk)", "nn",
		"Occitan",              "oc",    "Oriya",                 "or",    "Oromo",               "om",
		"Pashto",               "ps",    "Persian",               "fa",    "Polish",              "pl",
		"Portuguese (Brazil)",  "pt-BR", "Portuguese (Portugal)", "pt-PT", "Portuguese",          "pt",
		"Punjabi",              "pa",    "Quechua",               "qu",    "Romanian",            "ro",
		"Romansh",              "rm",    "Russian",               "ru",    "Scots Gaelic",        "gd",
		"Serbian",              "sr",    "Serbo-Croatian",        "sh",    "Sesotho",             "st",
		"Shona",                "sn",    "Sindhi",                "sd",    "Sinhalese",           "si",
		"Slovak",               "sk",    "Slovenian",             "sl",    "Somali",              "so",
		"Spanish",              "es",    "Sundanese",             "su",    "Swahili",             "sw",
		"Swedish",              "sv",    "Tajik",                 "tg",    "Tamil",               "ta",
		"Tatar",                "tt",    "Telugu",                "te",    "Thai",                "th",
		"Tigrinya",             "ti",    "Tonga",                 "to",    "Turkish",             "tr",
		"Turkmen",              "tk",    "Twi",                   "tw",    "Uighur",              "ug",
		"Ukrainian",            "uk",    "Urdu",                  "ur",    "Uzbek",               "uz",
		"Vietnamese",           "vi",    "Welsh",                 "cy",    "Xhosa",               "xh",
		"Yiddish",              "yi",    "Yoruba",                "yo",    "Zulu",                "zu"
	);

	if ($opt eq "dislpay") {
		print "Supported Languages list:\n";
		printf("%-22s:  %s\n", $_, $sup_lang{$_}) foreach (sort keys %sup_lang);
		exit 1;
	} elsif ($opt eq "list") {
		return %sup_lang;
	}
}
