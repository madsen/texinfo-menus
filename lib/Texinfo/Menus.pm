#---------------------------------------------------------------------
# $Id$
package Texinfo::Menus;
#
# Copyright 1994-2006 Christopher J. Madsen
#
# Update menus and node structure in Texinfo files
#---------------------------------------------------------------------

require 5.005;

use IO::File;
use strict;
use vars qw(
    $descColumn $level $masterMenu $menuMark $node $printKids $section
    $No_Comments $No_Detail $Verbose $VERSION
    @parents @ISA @EXPORT
    %children %desc %level %next %prev %section %title %up
);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(update_menus);

$VERSION = '1.00';

#=====================================================================
# Subroutines:
#---------------------------------------------------------------------
# Print an error message on STDERR and exit:
#
# Input:
#   filename:  The file containing the error
#   line:      The line number of the error (-1 means use $INPUT_LINE_NUMBER)
#   message:   The error message to display

sub abort
{
    my ($filename,$line,$message) = @_;

    $line = $. if $line eq '-1'; # $INPUT_LINE_NUMBER

    die "$filename:$line: $message\n";
} # end abort

#---------------------------------------------------------------------
sub update_menus
{
    my $master = shift @_;
    my %parms = @_;

    $descColumn  = $parms{description_column} || 32; # The column for menu descriptions
    $No_Comments = (exists $parms{comments} ? !$parms{comments} : 0);
    $No_Detail   = (exists $parms{detailed} ? !$parms{detailed} : 0);
    $Verbose     = $parms{verbose}; # Defaults to off

    $masterMenu = 0;
    $menuMark = '*';

    undef $node;        # We are not in any node yet
    undef $level;       undef %next;
    undef $section;     undef %prev;
    undef @parents;     undef %section;
    undef %children;    undef %title;
    undef %desc;        undef %up;

    readStructure($master);

    $next{"Top"} = $children{"Top"}->[0];

    writeMenus($master);
} # end file

#---------------------------------------------------------------------
# Generate the master menu:
#
# Input:
#   node:  The node we are in (usually "Top")
#
# Input Variables:
#   %children
#   %section
#   $No_Detail

sub printMasterMenu
{
    my $node = shift;

    local $masterMenu = 1;
    print "\@menu\n";
    printMenu(@{$children{$node}});
    unless ($No_Detail) {
        print "\n --- The Detailed Node Listing ---\n";
        local $printKids = 1 unless $No_Comments;
        my $child;
        foreach $child (@{$children{$node}}) {
            if (exists $children{$child}) {
                print "\n", ($section{$child} || $child), "\n\n";
                printMenu(@{$children{$child}});
            }
        } # end foreach
    } # end unless $No_Detail
    print "\@end menu\n";
} # end printMasterMenu

#---------------------------------------------------------------------
# Generate a menu:
#
# Input Variables:
#   $descColumn:  The column number for descriptions (0 is first column)
#   $masterMenu:  True prevents insertion of "@menu" and "@end menu".
#   $menuMark:    The mark that indicates a menu item (usually "*")
#   $printKids:   True inserts comments for child nodes

sub printMenu
{
    print "\@menu\n" unless $masterMenu;
    foreach $node (@_) {
        printf("%-${descColumn}s%s\n",
               ($title{$node}
                ? "$menuMark ${title{$node}}: ${node}." # Node with title
                : "$menuMark ${node}::"),               # Node with no title
               $desc{$node});
        printMenuComment(@{$children{$node}})
            if $printKids and exists $children{$node};
    } # end foreach $node
    print "\@end menu\n\n" unless $masterMenu;
} # end printMenu

#---------------------------------------------------------------------
# Generate comments for a submenu:
# Input Variables:
#   $masterMenu:  Must be True
#   $menuMark:    The mark that indicates a menu item (usually "*")
#   $printKids:   True inserts comments for child nodes

sub printMenuComment
{
    local $menuMark = $menuMark;
    if ($menuMark =~ /^\@c/) { $menuMark .= ' ' }
    else                     { $menuMark = '@c *' };
    &printMenu;
} # end printMenuComment

#---------------------------------------------------------------------
# Scan file for node structure and descriptions:
#
# Input:
#   $filename:  The file to scan
#
# Variables Created:
#   %children:
#     The children of a node, indexed by node name
#     Each entry is an array of node names (eg, @{$children{"Top"}}
#     is an array of all the children of the Top node, in the order
#     they occurred).
#   %desc:    Node descriptions, indexed by node name
#   %next:    The name of the next node, indexed by node name
#   %prev:    The name of the previous node, indexed by node name
#   %section: Section and subsection titles, indexed by node name
#   %title:   Node titles (menu-entry names), indexed by node name
#   %up:      The name of the "parent" node, indexed by node name
#
# Variables Used:
#   $node:     The node we are currently in
#   $level:    The level this node is at (0=Top, 1=Chapter, ...)
#   @parents:  A list of all the parent nodes of this node, including
#              the node itself ("Top", "Chapter Node", ... "This Node")

sub readStructure
{
    my $filename = $_[0];

    my $handle   = IO::File->new;

    open($handle,"<$filename") or abort($filename,0,"Unable to open");

  line:
    while (<$handle>) {
        if (/^\@node +([^,\n]+)/) {
            my $newNode = $1;
            abort($filename, -1, "Duplicate node name `$newNode'")
                if defined $prev{$newNode};
            if ($newNode eq 'Top') {
                $node = 'Top';
                @parents = ($node); # The Top node has no parents
                $prev{$node} = '(dir)';
                $up{$node} = '(dir)';
                $level = 0;
                next line;
            }
            $section = <$handle>;
            $section = <$handle> while $section =~ /^\@c(omment)? /;
            abort($filename, -1,
                  'Chapter structuring command required after `@node\'')
                unless ($section =~ /^\@([a-z]+) +(.+)$/);
            abort($filename,-1,"\`\@$1' is not a chapter structuring command")
                unless exists $level{$1};
            my $newLevel = $level{$1};
            abort($filename,-1,"Skipped level")
                if ($newLevel - $level) > 1;
            $section = $2;
            $section{$newNode} = $section;
            if (not $desc{$newNode}) {
                $desc{$newNode} = ($newNode ne $section ? $section : "");
            }
            $next{$newNode} = "";
            if ($newLevel < $level) {
                $next{$node} = "";
                my $prevNode = $parents[$newLevel];
                $next{$prevNode} = $newNode;
                $prev{$newNode}  = $prevNode;
            }
            else {
                $next{$node}    = $newNode  unless $newLevel > $level;
                $prev{$newNode} = $node;
            }
            $parents[$newLevel] = $newNode;
            $node  = $newNode;
            $level = $newLevel;
            my $parent = $parents[$level-1];
            $up{$node} = $parent;
            push @{$children{$parent}}, $node;
        } # end if @node
        elsif (/^\@menu/ .. /^\@end menu/) {
            next line unless /^(\@c )?\* /;

            my($node, $title, $desc);

            if (/\* +([^:]+):: *(.*)$/) {
                ($node, $title, $desc) = ($1, "", $2);
            }
            elsif (/\* +([^:]+): *([^,.\t\n]+)[,.\t\n] *(.*)$/) {
                ($node, $title, $desc) = ($2, $1, $3);
            }
            else {
                abort($filename,-1,"Bad menu entry");
            }
            $title{$node} = $title;
            if ($desc and $desc{$node}) {
                print STDERR <<EOT if $desc ne $desc{$node} and $Verbose;
$filename:$.: Warning: Multiple descriptions for node \`$node'
    \`$desc{$node}' overrides
    \`$desc'
EOT
                undef $desc;    # Don't overwrite the first description
            }
            $desc{$node}  = $desc if $desc;
        } # end elsif in @menu
        elsif (/^\@c(omment)? DESC: *(.*?) *$/) {
            # A DESC comment in the node overrides any previous description:
            if ($Verbose and $desc{$node} and $desc{$node} ne $2
                and $desc{$node} ne $section) {
                print STDERR <<EOT; # '
$filename:$.: Warning: Multiple descriptions for node \`$node'
    \`$2' overrides
    \`$desc{$node}'
EOT
# '
            } # end if node description is not section name or blank
            $desc{$node} = $2;
        } # end elsif DESC comment in node
        elsif (/^ *\@include +(\S+)\s/) {
            readStructure($1);
        }
    } # end while

    close $handle;
} # end readStructure

#---------------------------------------------------------------------
# Insert menus and node links:
#
# Input:
#   $filename:  The file to write
#
# Variables Used:
#   %children:
#     The children of a node, indexed by node name
#     Each entry is an array of node names (eg, @{$children{"Top"}}
#     is an array of all the children of the Top node, in the order
#     they occurred).
#   %desc:   Node descriptions, indexed by node name
#   %next:   The name of the next node, indexed by node name
#   %prev:   The name of the previous node, indexed by node name
#   %title:  Node titles (menu-entry names), indexed by node name
#   %up:     The name of the "parent" node, indexed by node name

sub writeMenus
{
    my $filename = $_[0];

    my ($menu,$node);
    my $deleteBlanks = 0;

    rename $filename,"$filename#~" or die "Unable to rename $filename";

    my $inHandle  = IO::File->new;
    my $outHandle = IO::File->new;

    open($inHandle,"<$filename#~") or die "Unable to open $filename#~";
    open($outHandle,">$filename")  or die "Unable to open $filename";

    my $oldHandle = select $outHandle;

    while (<$inHandle>) {
        if (/^ *\@include +(\S+)\s/) {
            local $_;         # Preserve the current line
            writeMenus($1);
        } # end if @include
        elsif (/^\@menu/) {
            if (ref($menu)) {
                if ($node eq 'Top') { printMasterMenu($node) }
                else                { printMenu(@$menu)      }
            }
            undef $menu;
        } # end elsif @menu
        elsif (/^\@node +([^,\n]+)/) {
            my $newNode = $1;
            if (ref($menu)) {
                if ($node eq 'Top') { printMasterMenu($node) }
                else                { printMenu(@$menu)      }
            }
            undef $menu;
            $node = $newNode;
            $_ = "\@node $node, $next{$node}, $prev{$node}, $up{$node}\n";
            $menu = $children{$node} if exists $children{$node};
        } # end elsif @node
    } # end while <$inHandle>
    continue {
        if (/^\@menu/ .. /^\@end menu/) {
            $deleteBlanks = 1;
        } else {
            print($_), $deleteBlanks = 0 unless ($deleteBlanks and /^ *$/);
        }
    } # end while <$inHandle> (continue block)

    select $oldHandle;
    close $inHandle;
    close $outHandle;
    unlink "$filename#~";
} # end writeMenus

#=====================================================================
# Main Program:
#=====================================================================
return 1 if caller;

#---------------------------------------------------------------------
# Parse arguments:
#---------------------------------------------------------------------
require Getopt::Long;
Getopt::Long->import(2.17); # need version 2.17 or later
Getopt::Long::Configure(qw(bundling no_getopt_compat));

Getopt::Long::GetOptions(
    'nocomments|c' => \$No_Comments,
    'nodetail|d'   => \$No_Detail,
    'verbose|v'    => \$Verbose,
    'help|?'       => \&usage,
    'version'      => \&usage
) or usage();;

sub usage
{
    print "up_menus $VERSION\n";
    exit if $_[0] and $_[0] eq 'version';
    print "\n" . <<'';
Usage:  up_menus [options] file
  -c, --nocomments  Do not add comments for subsections to the main menu
  -d, --nodetail    Do not add the detailed node listing to the main menu
  -v, --verbose     Print warning messages
  -?, --help        Display this usage information and exit
      --version     Display version number and exit

    exit;
} # end sub usage

#---------------------------------------------------------------------
# Process file:
#---------------------------------------------------------------------

usage() unless ($#ARGV == 0) and -e $ARGV[0];
file($ARGV[0]);
exit;

#=====================================================================
# Initialize variables:
#---------------------------------------------------------------------
BEGIN
{
    %level = (
        "chapter"             => 1,
        "section"             => 2,
        "subsection"          => 3,
        "subsubsection"       => 4,

        "unnumbered"          => 1,
        "unnumberedsec"       => 2,
        "unnumberedsubsec"    => 3,
        "unnumberedsubsubsec" => 4,

        "appendix"            => 1,
        "appendixsec"         => 2,
        "appendixsubsec"      => 3,
        "appendixsubsubsec"   => 4,

        "chapheading"         => 1,
        "heading"             => 2,
        "subheading"          => 3,
        "subsubheading"       => 4,
    );
} # end BEGIN

__END__

=head1 NAME

Texinfo::Menus - Update node links and menus in Texinfo documents

=head1 SYNOPSIS

  use Texinfo::Menus;

  update_menus($filename, verbose => 1);

=head1 DESCRIPTION

Texinfo::Menus exports just one function: B<update_menus>.  It updates
the menus and node links in a Texinfo file based on its chapter
structure.  The file may use C<@include> to include other files, which
may also C<@inlcude> other files.  Unlike the similar Emacs functions,
B<update_menus> does not require that each chapter be in a separate file.

The first node in the file should be named `Top'.

Each C<@node> command must be followed immediately by a Texinfo
structuring command (e.g, C<@chapter>, C<@section>, C<@appendix>).  A
comment may come between them, but nothing else.

A node can supply a menu description with a comment in the form:

 @c DESC: Menu description

=head1 OPTIONS

=over 5

=item B<comments>

B<update_menus> normally adds comments to the master menu to retain the
descriptions of subsection and lesser nodes.  (This is useful when the
subfiles are automatically generated and the descriptions are added by
hand.)  Use C<<comments => 0>> to prevent this.

=item B<detail>

Normally, B<update_menus> generates a detailed node listing (consisting of
the section nodes for each chapter) following the master menu.  Use
C<<detailed => 0>> to omit the detailed node listing.

=item B<verbose>

The B<verbose> option causes B<update_menus> to generate a warning
message if it finds multiple descriptions for a node (only one of
which will be used).  Use C<<verbose => 1>> to enable this.

=back

=head1 BUGS

Texinfo::Menus cannot handle C<@include> inside a menu.

=head1 AUTHOR

Christopher J. Madsen E<lt>F<cjm@pobox.com>E<gt>
