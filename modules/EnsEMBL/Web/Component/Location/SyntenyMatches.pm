package EnsEMBL::Web::Component::Location::SyntenyMatches;

### Module to replace part of the former SyntenyView, in this case displaying 
### a table of homology matches 

use strict;

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub caption {
  return 'Homology Matches';
}

sub content {
  my $self = shift;
  
  my $object      = $self->object;
  my $species     = $object->species;
  my $other       = $object->param('otherspecies') || $object->param('species') || $self->default_otherspecies;
  my $data        = $object->get_synteny_matches;
  (my $sp_tidy    = $species) =~ s/_/ /; 
  (my $other_tidy = $other)   =~ s/_/ /; 
  my $html;

  if (scalar @$data) {
    my $table = new EnsEMBL::Web::Document::SpreadSheet; 

    $table->add_spanning_headers(
      { title => "<i>$sp_tidy</i> Genes",         colspan => 2, width => '45%' },
      { title => ''                                                            }, ## empty header for arrows 
      { title => "<i>$other_tidy</i> Homologues", colspan => 2, width => '45%' },
      { title => ''                                                            }  ## empty header for multi species link 
    );
    
    $table->add_columns(
      { key => 'gene_ids', title => 'ID',       width => '20%', align => 'left'   },
      { key => 'gene_loc', title => 'Location', width => '15%', align => 'left'   },
      { key => 'arrow',    title => ' ',        width => '10%', align => 'center' },
      { key => 'homo_ids', title => 'ID',       width => '20%', align => 'left'   },
      { key => 'homo_loc', title => 'Location', width => '15%', align => 'left'   },
      { key => 'multi',    title => ' ',        width => '10%', align => 'left'   }
    );
    
    my $old_id;
    
    foreach my $row (@$data) {
      my ($sp_ids, $sp_loc, $other_ids, $other_loc, $multi);
      my $sp_stable_id    = $row->{'sp_stable_id'};
      my $other_stable_id = $row->{'other_stable_id'};
      my $r = sprintf '%s:%s-%s', $row->{'sp_chr'}, $row->{'sp_start'}, $row->{'sp_end'};
      
      if ($old_id ne $sp_stable_id) {        
        $sp_ids = sprintf '<a href="%s"><strong>%s</strong></a> (%s)', $object->_url({ type => 'Gene', action => 'Summary', r => $r, g => $sp_stable_id }), $row->{'sp_synonym'}, $sp_stable_id;
        $sp_loc = sprintf '<a href="%s">%s</a>', $object->_url({ action => 'View', r => $r, g => $sp_stable_id }), $r;
        $old_id = $sp_stable_id;
      }
      
      if ($other_stable_id) {
        my $other_r = sprintf '%s:%s-%s', $row->{'other_chr'}, $row->{'other_start'}, $row->{'other_end'};
        
        $other_ids = sprintf(
          '<a href="%s"><strong>%s</strong></a> (%s)', 
          $object->_url({ species => $other, type => 'Gene', action => 'Summary', r => $other_r, g => $other_stable_id }), 
          $row->{'other_synonym'}, 
          $other_stable_id
        );
        
        $other_loc = sprintf '<a href="%s">%s</a>', $object->_url({ species => $other, action => 'View', r => $other_r, g => $other_stable_id }), $other_r;
        $multi     = sprintf '<a href="%s">Multi-species view</a>', $object->_url({ action => 'Multi', r => $r, s1 => $other, r1 => $other_r, g1 => $other_stable_id });
      } else {
        $other_ids = 'No homologues';
      }
      
      $table->add_row({
        gene_ids => $sp_ids, 
        gene_loc => $sp_loc,
        arrow    => $row->{'homologue_no'} ? '-&gt;' : '', 
        homo_ids => $other_ids,
        homo_loc => $other_loc,
        multi    => $multi
      });
    }
    
    $html = $table->render;
  } else {
    $html = '<p>Sorry, there are no genes in this region. Use the links below to navigate to the nearest ones.</p>';
  }
  
  return $html;
}

1;
