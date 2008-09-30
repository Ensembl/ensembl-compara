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
  my $other = $object->param('otherspecies') || $object->param('species') || $self->default_otherspecies;
  (my $other_tidy = $other) =~ s/_/ /; 

  my $html;
  my $data = $object->get_synteny_matches;

  if (scalar(@$data)) {
    my $table = EnsEMBL::Web::Document::SpreadSheet->new(); 

    ## TODO : add sixth column 'alignment' once multicontigview is ported

    $table->add_spanning_headers(
      {'title' => "<i>$sp_tidy</i> Genes", 'colspan' => 2},
      {'title' => ''}, ## empty header for arrows 
      {'title' => "<i>$other_tidy</i> Homologues", 'colspan' => 2},
    );

    $table->add_columns(
      {'key' => 'gene_ids', 'title' => 'ID', 'width' => '20%', 'align' => 'left' },
      {'key' => 'gene_loc', 'title' => 'Location', 'width' => '20%', 'align' => 'left' },
      {'key' => 'arrow', 'title' => "&nbsp;", 'width' => '10%', 'align' => 'center' },
      {'key' => 'homo_ids', 'title' => 'ID', 'width' => '20%', 'align' => 'left' },
      {'key' => 'homo_loc', 'title' => 'Location', 'width' => '20%', 'align' => 'left' },
      );
    my ($sp_ids, $sp_loc, $arrow, $other_ids, $other_loc, $data_row);
    my $old_id = '';
    foreach my $row ( @$data ) {
      my $sp_stable_id        = $row->{'sp_stable_id'};
      my $sp_synonym          = $row->{'sp_synonym'};
      my $sp_chr              = $row->{'sp_chr'};
      my $sp_start            = $row->{'sp_start'};
      my $sp_end              = $row->{'sp_end'};
      my $sp_length           = $row->{'sp_length'};
      my $other_stable_id     = $row->{'other_stable_id'};
      my $other_synonym       = $row->{'other_synonym'};
      my $other_length        = $row->{'other_length'};
      my $other_chr           = $row->{'other_chr'};
      my $other_start         = $row->{'other_start'};
      my $other_end           = $row->{'other_end'};
      my $homologue_no        = $row->{'homologue_no'};

      $arrow = $homologue_no ? '-&gt;' : '';
      my $sp_links = '';
      if( $old_id ne $sp_stable_id ) { 
        $sp_ids = qq#<a href="/$species/Gene/Summary?g=$sp_stable_id"><strong>$sp_synonym</strong></a> ($sp_stable_id)#;
        $sp_loc = qq#<a href="/$species/Location/View?g=$sp_stable_id">$sp_chr:$sp_start-$sp_end</a>#;
        $old_id = $sp_stable_id;
      }
      if( $other_stable_id ) {
        $other_ids = qq#<a href="/$other/Gene/Summary?g=$other_stable_id"><strong>$other_synonym</strong></a> ($other_stable_id)#;
        $other_loc = qq#<a href="/$other/Location/View?g=$other_stable_id">$other_chr:$other_start-$other_end</a>#;
      } 
      else {
        $other_ids = 'No homologues';
        $other_loc = '';
      }
      $data_row = { 'gene_ids'  => $sp_ids, 'gene_loc' => $sp_loc, 'arrow' => $arrow, 
                    'homo_ids' => $other_ids, 'homo_loc' => $other_loc };
      $table->add_row( $data_row );
    }
    $html .= $table->render;
  }
  else {
    $html .= '<p>Sorry, there are no homologous genes in this region. Use the links below to navigate to the nearest matches.</p>';
  }
  return $html;
}

1;
