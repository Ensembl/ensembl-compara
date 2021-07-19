=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Location::SyntenyMatches;

### Module to replace part of the former SyntenyView, in this case displaying 
### a table of homology matches 

use strict;

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
  my $self        = shift;
  my $hub         = $self->hub;
  my $species     = $hub->species;
  my $other       = $hub->otherspecies;
  my $data        = $self->object->get_synteny_matches($other);
  (my $sp_tidy    = $species) =~ s/_/ /g; 
  (my $other_tidy = $other)   =~ s/_/ /g; 
  my $html;

  if (scalar @$data) {
    my $table = $self->new_table([], [], { exportable => 1, data_table => 1 }); 

    $table->add_columns(
      { key => 'gene_ids', title => "<i>$sp_tidy</i> genes",  width => '20%', align => 'left',    sort => 'html'   },
      { key => 'gene_loc', title => 'Location',               width => '15%', align => 'left',    sort => 'position_html' },
      { key => 'arrow',    title => ' ',                      width => '10%', align => 'center',  sort => 'none' },
      { key => 'homo_ids', title => "<i>$other_tidy</i> homologues",  width => '20%', align => 'left',  sort => 'html'   },
      { key => 'homo_loc', title => 'Location',               width => '15%', align => 'left',    sort => 'position_html' },
      { key => 'multi',    title => ' ',                      width => '10%', align => 'left',    sort => 'none'   }
    );
    
    my $old_id;
    
    foreach my $row (@$data) {
      my ($sp_ids, $sp_loc, $other_ids, $other_loc, $multi);
      my $sp_stable_id    = $row->{'sp_stable_id'};
      my $other_stable_id = $row->{'other_stable_id'};
      my $r = sprintf '%s:%s-%s', $row->{'sp_chr'}, $row->{'sp_start'}, $row->{'sp_end'};
      
      if ($old_id ne $sp_stable_id) {        
        $sp_ids = sprintf '<a href="%s"><strong>%s</strong></a> (%s)', $hub->url({ type => 'Gene', action => 'Summary', r => $r, g => $sp_stable_id }), $row->{'sp_synonym'}, $sp_stable_id;
        $sp_loc = sprintf '<a href="%s">%s</a>', $hub->url({ action => 'View', r => $r, g => $sp_stable_id }), $r;
        $old_id = $sp_stable_id;
      }
      
      if ($other_stable_id) {
        my $other_r = sprintf '%s:%s-%s', $row->{'other_chr'}, $row->{'other_start'}, $row->{'other_end'};
        
        $other_ids = sprintf(
          '<a href="%s"><strong>%s</strong></a> (%s)', 
          $hub->url({ species => $other, type => 'Gene', action => 'Summary', r => $other_r, g => $other_stable_id }), 
          $row->{'other_synonym'}, 
          $other_stable_id
        );
        
        $other_loc = sprintf '<a href="%s">%s</a>', $hub->url({ species => $other, action => 'View', r => $other_r, g => $other_stable_id }), $other_r;
        $multi     = sprintf '<a href="%s">Region Comparison</a>', $hub->url({ action => 'Multi', r => $r, s1 => $other, r1 => $other_r, g1 => $other_stable_id });
      } else {
        $other_ids = 'No homologues';
      }
      
      $table->add_row({
        gene_ids => $sp_ids, 
        gene_loc => $sp_loc,
        arrow    => $row->{'homologue_no'} ? '&rarr;' : '', 
        homo_ids => $other_ids,
        homo_loc => $other_loc,
        multi    => $multi
      });
    }
    
    $html = $table->render;
  } else {
    $html = '<p>Sorry, there are no genes in this region. Use the links in the navigation box to move to the nearest ones.</p>';
  }
  
  return $html;
}

1;
