# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::RdfParser;

=head1 NAME

  GO::Parsers::RdfParser     - 

=head1 SYNOPSIS


=cut

=head1 DESCRIPTION

=head1 AUTHOR

=cut

use Exporter;
use GO::Parsers::BaseParser;
@ISA = qw(GO::Parsers::BaseParser Exporter);

use RDF;
use RDF::Storage;
use RDF::Model;
use RDF::URI;
use RDF::Parser;

use GO::Model::Graph;
use Carp;
use FileHandle;
use strict qw(subs vars refs);


sub graph {
    my $self = shift;
    $self->{graph} = shift if @_;
    return $self->{graph};
}

sub init {
    my $self = shift;
    $self->graph(GO::Model::Graph->new);
    return $self;
}

sub parse_file {
    my ($self, $file) = @_;

    my $storage=new RDF::Storage("hashes", 
                                 "test",
                                 "new='yes',hash-type='bdb',dir='.'");
    die "Failed to create RDF::Storage\n" unless $storage;
    my $model=new RDF::Model($storage, "");
    my $uri=new RDF::URI("file:$file");
    my $baseuri=new RDF::URI(":x");
    my $parser=new RDF::Parser('repat');
    die "Failed to find parser\n" if !$parser;
    $parser->parse_into_model($uri, $baseuri, $model);

    my $statement =
      RDF::Statement->new_from_nodes(undef,undef,undef);
    my @match = $model->find_statements($statement);
    foreach my $s (@match) {
        my @trip =
          map {
              $self->fixnode($_);
          } ($s->object, $s->subject, $s->predicate);
        print "TRIP:@trip\n";
        map {
            $self->graph->add_term({acc=>$_});
        } @trip;
        $self->graph->add_relationship(@trip);
    }
    $self->graph->to_text_output();
}

sub fixnode {
    my $self = shift;
    my $n = shift;
    my $str = $n->as_string;
    if ( $str =~ m/http:.*\#/ ) {
        $str =~ s@http://www.geneontology.org/.*#@@;
          $str =~ s@http://www.w3.org/.*#@@;
            $str =~ s/^\[//;
        $str =~ s/\]$//;
    }
    $str;
}

1;
