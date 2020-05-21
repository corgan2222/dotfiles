#!/usr/bin/perl

#
# Lossless optimization for all JPEG files in a directory
# First Install & Link MOZJPEG
#Tested on Ubuntu 16.04 using pre-compiled binaries as per below:
#For 64bit: 
#wget https://mozjpeg.codelove.de/bin/mozjpeg_3.2_amd64.deb
#dpkg -i mozjpeg_3.2_amd64.deb
#ln -s /opt/mozjpeg/bin/jpegtran /usr/bin/jpegtran

#For 32bit: 
#wget https://mozjpeg.codelove.de/bin/mozjpeg_3.2_i386.deb
#dpkg -i mozjpeg_3.2_i386.deb
#ln -s /opt/mozjpeg/bin/jpegtran /usr/bin/jpegtran

use strict;
use File::Find;
use File::Copy;

# Read image dir from input
if (!$ARGV[0]) {
    print "Usage: $0 path_to_images\n";
    exit 1;
}
my @search_paths;
my $images_path = $ARGV[0];
if (!-e $images_path) {
    print "Invalid path specified.\n";
    exit 1;
} else {
    push @search_paths, $ARGV[0];
}

# Compress JPEGs
my $count_jpegs = 0;
my $count_modified = 0;
my $count_optimize = 0;
my $count_progressive = 0;
my $bytes_saved = 0;
my $bytes_orig = 0;

find(\&jpegCompress, @search_paths);

# Write summary
print "\n\n";
print "----------------------------\n";
print "  Sumary\n";
print "----------------------------\n";
print "\n";
print "  Inspected $count_jpegs JPEG files.\n";
print "  Modified $count_modified files.\n";
print "  Huffman table optimizations: $count_optimize\n";
print "  Progressive JPEG optimizations: $count_progressive\n";
print "  Total bytes saved: $bytes_saved (orig $bytes_orig, saved "
       . (int($bytes_saved/$bytes_orig*10000) / 100) . "%)\n";
print "\n";

sub jpegCompress()
{
    if (m/\.jpg$/i) {
        $count_jpegs++;

        my $orig_size = -s $_;
        my $saved = 0;

        my $fullname = $File::Find::dir . '/' . $_;

        print "Inspecting $fullname\n";

        # Run Progressive JPEG and Huffman table optimizations, then inspect
		# which was best.
        `/usr/bin/jpegtran -copy none -optimize "$_" > "$_.opt"`;
        my $opt_size = -s "$_.opt";

        `/usr/bin/jpegtran -copy none -progressive "$_" > "$_.prog"`;
        my $prog_size = -s "$_.prog";

        if ($opt_size && $opt_size < $orig_size && $opt_size <= $prog_size) {
            move("$_.opt", "$_");
            $saved = $orig_size - $opt_size;
            $bytes_saved += $saved;
            $bytes_orig += $orig_size;
            $count_modified++;
            $count_optimize++;

            print " -- Huffman table optimization: "
				. "saved $saved bytes (orig $orig_size)\n";

        } elsif ($prog_size && $prog_size < $orig_size) {
            move("$_.prog", "$_");
            $saved = $orig_size - $prog_size;
            $bytes_saved += $saved;
            $bytes_orig += $orig_size;
            $count_modified++;
            $count_progressive++;

            print " -- Progressive JPEG optimization: "
				. "saved $saved bytes (orig $orig_size)\n";
        }

        # Cleanup temp files
        if (-e "$_.prog") {
             unlink("$_.prog");
        }
        if (-e "$_.opt") {
            unlink("$_.opt");
        }
    }
}
