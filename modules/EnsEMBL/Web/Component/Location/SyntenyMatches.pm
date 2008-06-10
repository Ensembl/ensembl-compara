package EnsEMBL::Web::Component::Location::SyntenyMatches;

### Module to replace part of the former SyntenyView, in this case displaying 
### a table of homology matches 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  my $self = shift;
  return 'Homology Matches';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $species = $object->species;
  (my $sp_tidy = $species) =~ s/_/ /; 
  my $other = $object->param('otherspecies') || $object->param('species') 
                || ($species eq 'Homo_sapiens' ? 'Mus_musculus' : 'Homo_sapiens');
  (my $other_tidy = $other) =~ s/_/ /; 

  my $table = EnsEMBL::Web::Document::SpreadSheet->new(); 

  $table->add_columns(
      {'key' => 'genes', 'title' => "<i>$sp_tidy</i> Genes", 'width' => '40%', 'align' => 'left' },
      {'key' => 'arrow', 'title' => "&nbsp;", 'width' => '20%', 'align' => 'center' },
      {'key' => 'homologues', 'title' => "<i>$other_tidy</i> Homologues", 'width' => '40%', 'align' => 'left' },
      );
  my $data = $object->get_synteny_matches;
  my ($sp_links, $arrow, $other_links, $data_row);
  my $old_id = '';
  foreach my $row ( @$data ) {
    my $sp_stable_id        = $row->{'sp_stable_id'};
    my $sp_synonym          = $row->{'sp_synonym'};
    my $sp_length           = $row->{'sp_length'};
    my $other_stable_id     = $row->{'other_stable_id'};
    my $other_synonym       = $row->{'other_synonym'};
    my $other_length        = $row->{'other_length'};
    my $other_chr           = $row->{'other_chr'};
    my $homologue_no        = $row->{'homologue_no'};

    $arrow = $homologue_no ? '-&gt;' : '';
    my $sp_links = '';
    if( $old_id ne $sp_stable_id ) { 
      $sp_links = qq(<a href="/$species/Gene/Summary?g=$sp_stable_id"><strong>$sp_synonym</strong></a> \($sp_length\)<br />[<a href="/$species/Location/View?g=$sp_stable_id">View Region</a>]);
      $old_id = $sp_stable_id;
    }
    if( $other_stable_id ) {
      $other_links = qq(<a href="/$other/Gene/Summary?g=$other_stable_id"><strong>$other_synonym</strong></a><br />);
      $other_links .= "($other_chr: $other_length)<br />";
      $other_links .= qq([<a href="/$other/Location/View?g=$other_stable_id" title="Chr $other_chr: $other_length">View region</a>] [<a href="/$species/multicontigview?gene=$sp_stable_id;s1=$other;g1=$other_stable_id">View alignment</a>]);
    } else {
      $other_links = 'No homologues';
    }
    $data_row = { 'genes'  => $sp_links, 'arrow' => $arrow, 'homologues' => $other_links };
    $table->add_row( $data_row );
  }
  return $table->render;
}

1;
