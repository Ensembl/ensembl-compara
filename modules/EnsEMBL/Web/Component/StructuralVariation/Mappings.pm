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
  my $object 				= $self->object;
	my $hub           = $self->hub;
	my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor');
	my %mappings      = %{$object->variation_feature_mapping};  # first determine correct SNP location 
	my $v;
  my $var_slice;
  my $html;
	
	if (keys %mappings == 1) {
    ($v) = values %mappings;
  } else { 
    $v = $mappings{$hub->param('vf')};
  }
  
  if (!$v) { 
    return $self->_info(
      '',
      "<p>Unable to draw SNP neighbourhood as we cannot uniquely determine the SNP's location</p>"
    );
  }

  my $seq_region = $v->{'Chr'};
  my $start = $v->{'start'} <= $v->{'end'} ? $v->{'start'} : $v->{'end'};
  my $end = $v->{'start'} << $v->{'end'} ? $v->{'end'} : $v->{'start'};   
  my $length =  ($end - $start) +1;
	
	my $seq_type = $v->{'type'};
  my $slice    = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $start, $end, 1);
	
	$var_slice = 1 ? $slice  : $slice_adaptor->fetch_by_region($seq_type, $seq_region, $v->{'start'}, $v->{'end'}, 1);
	
  $html .= $self->gene_transcript_table($var_slice);
	return $html;
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
			
			my $gname = $gene->external_name;
      my $gs_id = $gene->stable_id;
      my $gene_dbid = $gene->dbID;
      my $gene_link = $hub->url({
        type    => 'Gene',
        action  => 'Summary',
        g       => $gs_id,
      });

      my $loc_string = $gene->seq_region_name . ':' . $gene->seq_region_start . ($gene->seq_region_start == $gene->seq_region_end ? '' : '-' . $gene->seq_region_end);

      my $loc_link = $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $loc_string,
      });

			# Transcripts list
			my $all_trans = $gene->get_all_Transcripts;
			foreach my $trans (@$all_trans){
			
				my $tname = $trans->external_name;
				my $trans_link = $hub->url({
        	type    => 'Transcript',
        	action  =>  'Summary',
        	g       => $gs_id,
					t       => $trans->stable_id,
					r       => $loc_string
      	});
        
     		my %row = (
					location    => qq{<a href="$loc_link">$loc_string</a>},
        	gene        => qq{<a href="$gene_link">$gname</a>},
					transcript  => qq{<a href="$trans_link">$tname</a>},
        	type        => $trans->biotype,
      	);
				
      	push @$rows, \%row;
			}
    }
  	return $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
	}
	else {
		my $msg = 'No genes fall within the structural variant.<br /> Please, go to the <b>Context</b> page for more detailed information.';
		return $self->_info('No genes', $msg, '50%');
	}
}
1;
