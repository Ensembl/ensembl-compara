# $Id$

package EnsEMBL::Web::Component::StructuralVariation::Mappings;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object         = $self->object;
  my $hub           = $self->hub;
  my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor');
  my %mappings      = %{$object->variation_feature_mapping};  # first determine correct SNP location 
  my $v;
  
  if (keys %mappings == 1) {
    ($v) = values %mappings;
  } elsif (!$hub->param('svf')){
    return $self->_info(
      'A unique location can not be determined for this variation',
      $object->not_unique_location);
  } else { 
    $v = $mappings{$hub->param('svf')};
  }
  
  if (!$v) { 
    return $self->_info(
      'Location problem',
      "<p>Unable to draw structural variant neighbourhood as we cannot uniquely determine the structural variant's location</p>"
    );
  }

  my $seq_region = $v->{'Chr'};
  my $start = $v->{'start'} <= $v->{'end'} ? $v->{'start'} : $v->{'end'};
  my $end = $v->{'start'} << $v->{'end'} ? $v->{'end'} : $v->{'start'};   
  my $length =  ($end - $start) +1;
  
  my $seq_type = $v->{'type'};
  my $slice    = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $start, $end, 1);
  
  return $self->gene_transcript_table($slice);
}


sub gene_transcript_table {
  my $self   = shift;
  my $slice  = shift;
  my $hub    = $self->hub;
  my $title    = 'Genes / Transcripts';
  my $table_id = 'gene';
  
  my $columns = [
     { key => 'location',   sort => 'position_html', title => 'Chr:bp'          },
     { key => 'gene',       sort => 'string',        title => 'Gene name'       },
     { key => 'transcript', sort => 'string',        title => 'Transcript name' }, 
     { key => 'type',       sort => 'string',        title => 'Type'            },
  ];

  my $rows;
  
  # Genes list
  my $genes  = $slice->get_all_Genes;
  if (scalar @{$genes}) {
    foreach my $gene (@$genes){
      
      my $gs_id = $gene->stable_id;
      my $gene_dbid = $gene->dbID;
      my @entries    = grep $_->database eq 'HGNC', @{$gene->get_all_DBEntries};
      my $gene_hgnc  = scalar @entries ? ' <span class="small" style="white-space:nowrap;"><b>HGNC: </b>' . $entries[0]->display_id.'</span>' : '';
      
      
      my $gene_link = $hub->url({
        type    => 'Gene',
        action  => 'StructuralVariation_Gene',
        g       => $gs_id,
      });

      my $g_start = $gene->seq_region_start;
      my $g_end   = $gene->seq_region_end;
      
      my $loc_string = $gene->seq_region_name . ':' . $g_start . ($g_start == $g_end ? '' : '-' . $g_end);

      my $loc_link = $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $loc_string,
      });

      # Transcripts list
      foreach my $trans (@{$gene->get_all_Transcripts}){
      
        my $ts_id = $trans->stable_id;
        my $trans_link = $hub->url({
          type    => 'Gene',
          action  => 'StructuralVariation_Gene',
          g       => $gs_id,
          t       => $ts_id,
        });
        
         my %row = (
          location    => qq{<a href="$loc_link">$loc_string</a>},
          gene        => qq{<a href="$gene_link">$gs_id</a>$gene_hgnc},
          transcript  => qq{<a href="$trans_link">$ts_id</a>},
          type        => $trans->biotype,
        );
        
        push @$rows, \%row;
      }
    }
    return $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
  }
  else {
     my $url  = $self->hub->url({
      species   => $self->hub->species,
      type      => 'StructuralVariation',
      action    => 'Context'
     });
    
    my $msg = qq{No genes fall within the structural variant.<br /> Please, go to the <a href="$url">Genomic context</a> page for more detailed information.};
    return $self->_info('No genes', $msg, '50%');
  }
}
1;
