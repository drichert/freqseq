#!/usr/bin/perl -w 

use strict; 
use warnings;
use Getopt::Std;
use Cwd;
use File::Spec;
use File::Copy;
use File::Basename;
use File::Path;

my %opts=();
getopts("i:o:", \%opts);

my $usage_msg = 'Usage: freqseq.pl -i <input file> -o <output file>'."\n";

my($input_file, $output_file);
if(!$opts{i} || !$opts{o}){
	die($usage_msg);
}else{
	$input_file = File::Spec->rel2abs($opts{i});
	$output_file = File::Spec->rel2abs($opts{o});
}


# Generate a random string to use for the temporary directory
my $chars = '012345789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
my $num_chars = 8; my $i = 0;
my $dirname;
while($i < $num_chars){
	$dirname .= substr($chars, int(rand(length($chars)-1)), 1);
	$i++;
}
my $tmpdir = File::Spec->tmpdir();
$dirname = "$tmpdir/freqseq-$dirname";

# Create the temporary directory to store audio segements
mkdir("$dirname");
chdir("$dirname");

######################################

sub convert_to_wav {
	my $filename = shift;
	`sox $filename $filename.wav`
}

sub get_freq {
	my $filename = shift;
	my $freq = `sox $filename -n stat 2>&1 |grep cy |awk '{print \$3}'`;
	if($freq){ 
		chomp $freq;
		return $freq; 
	}else{ 
		return 0; 
	}
}

######################################

# print get_freq($input_file);	
# print $input_file."\n";

my $input_file_basename = basename($input_file);

# Copy the original sound file to the temp directory
copy($input_file, "$dirname/$input_file_basename");

# Set up the $working_original filename (this will be the 
# filename used for the input file to be processed).
# Convert the input file to WAV (if it's not already)
my $working_original;
if( $input_file_basename !~ m/\.wav$/ ){
	$working_original = "$input_file_basename.wav";
	`sox $input_file_basename $working_original`;
}else{
	$working_original = $input_file_basename;
} 
	
# Chop the file into segments
`aubiocut -c -L -i $working_original`;

# Delete the original(s)
if( $working_original eq $input_file_basename ){
	unlink $working_original;
}else{  # removce the original file (of alternate format) and the converted WAV file
	unlink $working_original, $input_file_basename;
}

# Arrange the segment files 
my @segment_files = glob '*.wav';
my $segment_freq;
my %segment_freq_hash;
foreach(@segment_files){
	$segment_freq_hash{$_} = get_freq($_);
}

my $segment_filename;
# my $a; my $b; # for sorting
my $last_cat = '';
my $count = 0;
my @file_list = ();
my $cat_count = 0;
foreach $segment_filename (sort { $segment_freq_hash{$a} <=> $segment_freq_hash{$b} } keys %segment_freq_hash){	
	# print "$segment_filename $segment_freq_hash{$segment_filename}\n";
	push(@file_list, $segment_filename);
	
	$count++;
	if( $count >= 30 ){
		`sox $last_cat @file_list cat-$cat_count.wav`;
		unlink $last_cat;
		unlink @file_list;
		@file_list = ();
		$last_cat = "cat-$cat_count.wav";
		$cat_count++;
		$count = 0;
	}
}

@file_list = grep( !/^cat-/, glob('*.wav') );
`sox $last_cat @file_list cat-$cat_count.wav`;
copy("cat-$cat_count.wav", $output_file); 	

# Clean up
rmtree($dirname);


	

