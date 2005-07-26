# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::MeshParser;

=head1 NAME

  GO::Parsers::MeshParser     - Parses Mesh ascii text files

=head1 SYNOPSIS

  do not use this class directly; use GO::Parser

=cut

=head1 DESCRIPTION

=head1 AUTHOR

=cut

use Exporter;
use GO::Parsers::BaseParser;
@ISA = qw(GO::Parsers::BaseParser Exporter);

use Carp;
use FileHandle;
use strict qw(subs vars refs);

sub parse_file {
    my ($self, $file, $dtype) = @_;
    $self->file($file);

    my $fh = new FileHandle($file);
    if (!$fh) {confess "Couldn't open '$file': $!"};

    $/ = '*NEWRECORD';

    my %treenode2acc = ();

    $self->start_event("subgraph");

    my @accs = ();

    my $lnum = 0;

  PARSELINE:
    while (my $block = <$fh>) {
	chomp $block;
        next unless $block;
	++$lnum;
        $self->line($block);
        $self->line_no($lnum);

        my @lines = split(/\n/, $block);
        my ($name, $acc, $def, @mn);
        map {
            if (/(\w+) = (.*)/) {
                my ($key, $val) = ($1, $2);
                if ($key eq "MH") {
                    $name = $val;
                }
                if ($key eq "UI") {
                    $acc = $val;
                }
                if ($key eq "MS") {
                    $def = $val;
                }
                if ($key eq "MN") {
                    push(@mn, $val);
                }
            }
        } @lines;
        
        $self->event('term',
                     [
                      [name=>$name],
                      [acc=>"Mesh:$acc"],
                      [term_type=>"Mesh"],
                     ]
                    );
        $self->event('def',
                     [
                      ['godef-goid'=>$acc],
                      ['godef-definition'=>$def],
                     ]
                    ) if $def;
        push(@accs, $acc);
        foreach (@mn) {
            $treenode2acc{$_} = $acc;
        }
    }
    foreach my $tn (keys %treenode2acc) {
        my $child = $treenode2acc{$tn};
        my $pn = $tn;
        $pn =~ s/\.(\d+)$//;
        if ($pn ne $tn) {
            my $parent = $treenode2acc{$pn};
            $self->event("term" => [
                                    [acc=>$child],
                                    [rel=> [
                                            [type => 'isa'],
                                            [obj=>$parent]
                                           ]
                                    ]
                                   ]
                        );
        }
    }

    $self->end_event("subgraph");
    $self->parsed_ontology(1);
#    use Data::Dumper;
#    print Dumper $self;
}


1;
