package EnsEMBL::Web::Component;

use strict;

use base qw(EnsEMBL::Web::Root Exporter);

use Exporter;

our @EXPORT_OK = qw(cache cache_print);
our @EXPORT = @EXPORT_OK;

use CGI qw(escape);
use Data::Dumper;
use Text::Wrap qw(wrap);

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);

use Bio::EnsEMBL::ExternalData::DAS::Coordinator;
use EnsEMBL::Web::Component::Export;
use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::TmpFile::Text;

### Attach all das sources from an image config!

sub _attach_das {
  my( $self, $wuc ) = @_;

  ## Look for all das sources which are configured and turned on!

  my @das_nodes = map {
      $_->get('glyphset') eq '_das' && $_->get('display') ne 'off'
    ? @{ $_->get('logicnames')||[] }
    : ()
  }  $wuc->tree->nodes;
  return unless @das_nodes; # Return if no sources to be drawn!
 
  ## Check to see if they really exists... and get entries fro get_all_das call

  my %T         = %{ $ENSEMBL_WEB_REGISTRY->get_all_das( $self->object->species ) };
  my @das_sources = @T{ @das_nodes };
  return unless @das_sources; # Return if no sources exist!

  ## Cache the DAS Coordinator object (with key das_coord)

  $wuc->cache( 'das_coord',  
    Bio::EnsEMBL::ExternalData::DAS::Coordinator->new(
      -sources => \@das_sources,
      -proxy   => $self->object->species_defs->ENSEMBL_WWW_PROXY,
      -noproxy => $self->object->species_defs->ENSEMBL_NO_PROXY,
      -timeout => $self->object->species_defs->ENSEMBL_DAS_TIMEOUT
    )
  );
}

sub _info_panel {
  my($self,$class,$caption,$desc,$width) = @_;
  return sprintf '<div style="width:%s" class="%s"><h3>%s</h3><div class="error-pad">%s</div></div>',
    $width || $self->image_width.'px', $class, $caption, $desc;
}

## Fatal error message... couldn't perform action
sub _error   { my $self = shift; return $self->_info_panel( 'error',   @_ ); }

## Error message... but not fatal!
sub _warning { my $self = shift; return $self->_info_panel( 'warning', @_ ); }

## Extra information 
sub _info    { my $self = shift; return $self->_info_panel( 'info',    @_ ); }

## Extra information - panel will eventually be removable - when extra session stuff is added
sub _hint    {
  my($self,$ID,$caption,$desc,$width) = @_;
  return sprintf '<div id="%s" style="width:%s" class="hint hint_flag"><h3>%s</h3><div class="error-pad">%s</div></div>',
    $ID, $width || $self->image_width.'px', $caption, $desc;
}

sub _export_image {
  my( $self, $image, $flag ) = @_;
	$image->{export} = 'iexport' . ($flag ? " $flag" : '');
	my( $format,$scale ) = $self->object->param('export' ) ? split( /-/, $self->object->param('export'),2) : ('',1);
	$scale eq 1 if $scale <= 0;
	my %FORMATS = EnsEMBL::Web::Constants::FORMATS;
	if( $FORMATS{ $format } ) {  	
  	$image->drawable_container->{'config'}->set_parameter('sf',$scale);
		( my $comp = ref($self) ) =~ s/[^\w\.]+/_/g;
		my $filename = "$comp-".$self->object->_filename().'-'.$scale.'.'.$FORMATS{$format}{'extn'};
		if( $self->object->param( 'download' ) ) {
  		$self->object->input->header( -type => $FORMATS{$format}{'mime'}, -attachment => $filename );
		} else {
  		$self->object->input->header( -type => $FORMATS{$format}{'mime'}, -inline => $filename );
		}
		
        if ($FORMATS{$format}{'extn'} eq 'txt') {
          print $image->drawable_container->{'export'};
          return 1;
        }
		
  	$image->render( $format );
    return 1;
  }
  
  return 0;
}

sub image_width {
  my $self = shift;
  return $ENV{'ENSEMBL_IMAGE_WIDTH'};
}

sub new {
  my( $class, $object ) = shift;
  my $self = { 'object' => shift, };
  bless $self,$class;
  $self->_init();
  return $self;
}

sub object {
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->{'object'};
}

sub cacheable {
  my $self = shift;
  $self->{'cacheable'} = shift if @_;
  return $self->{'cacheable'};
}

sub ajaxable {
  my $self = shift;
  $self->{'ajaxable'} = shift if @_;
  return $self->{'ajaxable'};
}

sub configurable {
  my $self = shift;
  $self->{'configurable'} = shift if @_;
  return $self->{'configurable'};
}

sub cache_key {
  return undef;
}

sub _init {
  return;
}

sub caption {
  return undef;
}

sub cache {
  my( $panel, $obj, $type, $name ) = @_;
  my $cache = new EnsEMBL::Web::TmpFile::Text(
    prefix   => $type,
    filename => $name,
  );
  return $cache;
}

sub cache_print {
  my( $cache, $string_ref ) =@_;
  $cache->print( $$string_ref ) if $string_ref;
}

sub site_name {
  my $self = shift;
  our $sitename = $SiteDefs::ENSEMBL_SITETYPE;
  return $sitename;
}

sub modal_form {
  ## Creates a modal-friendly form with hidden elements to automatically pass 
  ##_referer and x_requested_with - and to optionally handle wizard buttons
  my ($self, $name, $action, $options) = @_;
  my $form_action = $action;
  if ($options->{'wizard'}) {
    my $species = $ENV{'ENSEMBL_TYPE'} eq 'UserData' ? $self->object->data_species : $self->object->species;
    if ($species) {
      $form_action = "/$species";
    }
    $form_action .= '/'.$ENV{'ENSEMBL_TYPE'}.'/Wizard';
  }
  my $form = EnsEMBL::Web::Form->new($name, $form_action, 'post');
  my $label = $options->{'label'} || 'Next >';

  $form->add_element( 'type' => 'Hidden', 'name' => '_referer', 'value' => $self->object->param('_referer'));
  $form->add_element( 'type' => 'Hidden', 'name' => 'x_requested_with', 'value' => $self->object->param('x_requested_with'));
  if ($options->{'wizard'}) {
    unless (defined($options->{'back_button'}) && $options->{'back_button'} == 0) { 
      $form->add_button('type' => 'Submit', 'name' => 'wizard_submit', 'value' => '< Back');
    }
    ## Include current and former nodes in _backtrack
    if (my @tracks = $self->object->param('_backtrack')) {
      foreach my $step (@tracks) {
        next unless $step;
        $form->add_element('type' => 'Hidden', 'name' => '_backtrack', 'value' => $step);
      }
    }
    $form->add_element('type' => 'Hidden', 'name' => '_backtrack', 'value' => $ENV{'ENSEMBL_ACTION'});

    $form->add_button('type' => 'Submit', 'name' => 'wizard_submit', 'value' => $label);
    $form->add_element('type' => 'Hidden', 'name' => 'wizard_next', 'value' => $action);
    $form->add_element('type' => 'Hidden', 'name' => 'wizard_ajax_submit', 'value' => '' );
  }
  else {
    $form->add_button('type' => 'Submit', 'name' => 'submit', 'value' => $label);
  }

  return $form;
}


## DATA-MUNGING METHODS FOR GENOMIC PAGES -------------------------------------------------------------------

sub new_image {
  my $self = shift;
  my $object = $self->object;
  
  my %FORMATS = EnsEMBL::Web::Constants::FORMATS;
  
  # Set text export on image config
  if ($FORMATS{$object->param('export')}{'extn'} eq 'txt') {
    my $image_config = ref $_[0] eq 'ARRAY' ? $_[0][1] : $_[1];
    
    $image_config->set_parameter('text_export', $object->param('export'));
  }
  
  my $species_defs = $object->species_defs;
  my $timer = $species_defs->timer;
  my $image = EnsEMBL::Web::Document::Image->new( $species_defs );
     $image->drawable_container = Bio::EnsEMBL::DrawableContainer->new( @_ );
     $image->set_extra( $object );
     if ($object->prefix) {
       $image->prefix($object->prefix);
     }
  return $image;
}

sub new_vimage {
  my $self  = shift;
  my $object = $self->object;
  my $image = EnsEMBL::Web::Document::Image->new( $object->species_defs );
     $image->drawable_container = Bio::EnsEMBL::VDrawableContainer->new( @_ );
     $image->set_extra( $object );
  return $image;
}

sub new_karyotype_image {
  my $self = shift;
  my $object = $self->object;
  my $image = EnsEMBL::Web::Document::Image->new( $object->species_defs );
     $image->set_extra( $object );
     $image->{'object'} = $object;
  return $image;
}

sub _matches {
  my ( $self, $key, $caption, @keys ) = @_;
  my $object = $self->object;
  my $label  = $object->species_defs->translate( $caption );
  my $obj    = $object->Obj;

  # Check cache
  unless ($object->__data->{'links'}){
    my @similarity_links = @{$object->get_similarity_hash($obj)};
    return unless (@similarity_links);
    $self->_sort_similarity_links( @similarity_links);
  }

  my @links = map { @{$object->__data->{'links'}{$_}||[]} } @keys;
  return unless @links;

  my $db = $object->get_db();
  my $entry = $object->gene_type || 'Ensembl';

  # add table call here
  my $html = qq(<p><strong>This $entry entry corresponds to the following database identifiers:</strong></p>);
  $html .= qq(<table cellpadding="4">);
  if( $keys[0] eq 'ALT_TRANS' ) {
      @links = $self->remove_redundant_xrefs(@links);
  }
  my $old_key = '';
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if( $key ne $old_key ) {
      if($old_key eq "GO") {
        $html .= qq(<div class="small">GO mapping is inherited from swissprot/sptrembl</div>);
      }
      if( $old_key ne '' ) {
        $html .= qq(</td></tr>);
      }
      $html .= qq(<tr><th style="white-space: nowrap; padding-right: 1em">$key:</th><td>);
      $old_key = $key;
    }
    $html .= $text;
  }
  $html .= qq(</td></tr></table>);

  return $html;
}

sub _sort_similarity_links {
  my $self             = shift;
  my $object           = $self->object;
  my @similarity_links = @_;
  my $database = $object->database;
  my $db       = $object->get_db() ;
  my $urls     = $object->ExtURL;
  my @links ;

  #default link to featureview is to retrieve an Xref
  my $fv_type = $object->action eq 'Oligos' ? 'OligoFeature' : 'Xref';

  my (%affy, %exdb);
  # @ice names
  foreach my $type (sort {
    $b->priority        <=> $a->priority ||
    $a->db_display_name cmp $b->db_display_name ||
    $a->display_id      cmp $b->display_id
  } @similarity_links ) {
    my $link = "";
    my $join_links = 0;
    my $externalDB = $type->database();
    my $display_id = $type->display_id();
    my $primary_id = $type->primary_id();
    next if ($type->status() eq 'ORTH');               # remove all orthologs
    next if lc($externalDB) eq "medline";              # ditch medline entries - redundant as we also have pubmed
    next if ($externalDB =~ /^flybase/i && $display_id =~ /^CG/ ); # Ditch celera genes from FlyBase
    next if $externalDB eq "Vega_gene";                # remove internal links to self and transcripts
    next if $externalDB eq "Vega_transcript";
    next if $externalDB eq "Vega_translation";
    next if ($externalDB eq 'OTTP') && $display_id =~ /^\d+$/; #don't show vega translation internal IDs
    if( $externalDB eq "GO" ){
      push @{$object->__data->{'links'}{'go'}} , $display_id;
      next;
    } elsif ($externalDB eq "GKB") {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}} , $type ;
      next;
    }
    my $text = $display_id;
    (my $A = $externalDB ) =~ s/_predicted//;
    if( $urls and $urls->is_linked( $A ) ) {
      my $link;
      $link = $urls->get_url( $A, $primary_id );

      my $word = $display_id;
      if( $A eq 'MARKERSYMBOL' ) {
        $word = "$display_id ($primary_id)";
      }
      if( $link ) {
        $text = qq(<a href="$link">$word</a>);
      } else {
        $text = qq($word);
      }
    }
    if( $type->isa('Bio::EnsEMBL::IdentityXref') ) {
      $text .=' <span class="small"> [Target %id: '.$type->target_identity().'; Query %id: '.$type->query_identity().']</span>';
      $join_links = 1;
    }
    unless ($object->Obj->isa("Bio::EnsEMBL::Gene")) {
      if( ( $object->species_defs->ENSEMBL_PFETCH_SERVER ) &&
	    ( $externalDB =~/^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i ) ) {
	my $seq_arg = $display_id;
	$seq_arg = "LL_$seq_arg" if $externalDB eq "LocusLink";
	$text .= sprintf( ' [<a href="/%s/Transcript/Similarity/Align?t=%s;sequence=%s;db=%s">align</a>] ',
			  $object->species, $object->stable_id, $seq_arg, $db );
      }
    }
    if($externalDB =~/^(SWISS|SPTREMBL)/i) { # add Search GO link
      $text .= ' [<a href="'.$urls->get_url('GOSEARCH',$primary_id).'">Search GO</a>]';
    }
    if( $type->description ) {
      ( my $D = $type->description ) =~ s/^"(.*)"$/$1/;
      $text .= "<br />".CGI::escapeHTML($D);
      $join_links = 1;
    }
    if( $join_links  ) {
      $text = qq(\n <div>$text);
    } else {
      $text = qq(\n <div class="multicol">$text);
    }
    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if( $externalDB =~ /^AFFY_/i) {
      next if ($affy{$display_id} && $exdb{$type->db_display_name}); ## remove duplicates
      $text = "\n".'  <div class="multicol"> '.$display_id;
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }

    #add link to featureview
    my $link_name = ($fv_type eq 'OligoFeature') ? $display_id : $primary_id;
    my $link_type = ($fv_type eq 'OligoFeature') ? $fv_type : $fv_type . "_$externalDB";
    my $k_url = $object->_url({
	'type'   => 'Location',
	'action' => 'Genome',
	'id'     => $link_name,
	'ftype'  => $link_type,
    });
    $text .= qq(  [<a href="$k_url">view all locations</a>]);

    $text .= '</div>';
    push @{$object->__data->{'links'}{$type->type}}, [ $type->db_display_name || $externalDB, $text ] ;
  }
}

sub _export { return EnsEMBL::Web::Component::Export::export(@_); }

sub remove_redundant_xrefs {
  my ($self,@links) = @_;
  my %priorities;
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if ($text =~ />OTT|>ENST/) {
      $priorities{$key} = $text;
    }
  }
  foreach my $type (
    'Transcript having exact match between ENSEMBL and HAVANA',
    'Ensembl transcript having exact match with Havana',
    'Havana transcript having same CDS',
    'Ensembl transcript sharing CDS with Havana',
    'Havana transcripts') {
    if ($priorities{$type}) {
      my @munged_links;
      $munged_links[0] = [ $type, $priorities{$type} ];
      return @munged_links;;
    }
  }
  return @links;
}

sub _warn_block {
### Simple subroutine to dump a formatted "warn" block to the error logs - useful when debugging complex
### data structures etc... 
### output looks like:
###
###  ###########################
###  #                         #
###  # TEXT. TEXT. TEXT. TEXT. #
###  # TEXT. TEXT. TEXT. TEXT. #
###  # TEXT. TEXT. TEXT. TEXT. #
###  #                         #
###  # TEXT. TEXT. TEXT. TEXT. #
###  # TEXT. TEXT. TEXT. TEXT. #
###  #                         #
###  ###########################
###

  my $self = shift;

  my $width       = 128;
  my $border_char = '#';
  my $template = sprintf "%s %%-%d.%ds %s\n", $border_char, $width-4,$width-4, $border_char;
  my $line     = $border_char x $width;
  warn "\n";
  warn "$line\n";
  $Text::Wrap::columns = $width-4;
  foreach my $l (@_) {
    warn sprintf $template;
    my $lines = wrap( "","", $l );
    foreach ( split /\n/, $lines ) { 
      warn sprintf $template, $_;
    }
  }
  warn sprintf $template;
  warn "$line\n";
  warn "\n";
}

# Used by Compara_Alignments, Gene::GeneSeq and Location::SequenceAlignment
sub get_sequence_data {
  my $self = shift;
  my ($slices, $config) = @_;

  my @sequence;
  my @markup;
  
  foreach my $sl (@$slices) {
    my $mk = {};
    my $slice = $sl->{'slice'};
    my $name = $sl->{'name'};
    my $seq = uc $slice->seq(1);
    
    my ($slice_start, $slice_end, $slice_length, $slice_strand) = ($slice->start, $slice->end, $slice->length, $slice->strand);
    
    $config->{'length'} ||= $slice_length;
    
    if ($config->{'match_display'} && $name ne $config->{'ref_slice_name'}) {      
      my $i = 0;
      my @cmp_seq = map {{ 'letter' => ( $config->{'ref_slice_seq'}->[$i++] eq $_ ? '.' : $_ ) }} split(//, $seq);

      while ($seq =~ m/([^~]+)/g) {
        my $reseq_length = length $1;
        my $reseq_end = pos $seq;
        
        $mk->{'comparisons'}->{$reseq_end-$_}->{'resequencing'} = 1 for (1..$reseq_length);
      }
      
      push (@sequence, \@cmp_seq);
    } else {
      push (@sequence, [ map {{ 'letter' => $_ }} split(//, $seq) ]);
    }
    
    if ($config->{'region_change_display'} && $name ne $config->{'species'}) {
      my $s = 0;
      
      # We don't want to mark the very end of the sequence, so don't loop for the last element in the array
      for (0..scalar(@{$sl->{'underlying_slices'}})-2) {
        my $end_region   = $sl->{'underlying_slices'}->[$_];
        my $start_region = $sl->{'underlying_slices'}->[$_+1];
        
        $s += length($end_region->seq(1));
        
        $mk->{'region_change'}->{$s-1} = $end_region->name   . ' END';
        $mk->{'region_change'}->{$s}   = $start_region->name . ' START';

        for ($s-1..$s) {
          if ($mk->{'region_change'}->{$_} =~ /.*gap.* (\w+)/) {
            $mk->{'region_change'}->{$_} = "GAP $1";
          }
        }
      }
    }
    
    # Markup inserts on comparisons
    if ($config->{'align'}) {
      while ($seq =~  m/(\-+)[\w\s]/g) {
        my $ins_length = length $1;
        my $ins_end = pos($seq) - 1;
        
        $mk->{'comparisons'}->{$ins_end-$_}->{'insert'} = "$ins_length bp" for (1..$ins_length);
      }
    }
    
    # Get variations
    if ($config->{'snp_display'}) {
      my $snps = [];
      my $u_snps = {};
    
      eval {
        $snps = $slice->get_all_VariationFeatures;
      };
      
      if (scalar @$snps) {
        foreach my $u_slice (@{$sl->{'underlying_slices'}||[]}) {
          next if ($u_slice->seq_region_name eq 'GAP');
          
          if (!$u_slice->adaptor) {
            my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($name, $config->{'db'}, 'slice');
            $u_slice->adaptor($slice_adaptor);
          }
          
          eval {
            map { $u_snps->{$_->variation_name} = $_ } @{$u_slice->get_all_VariationFeatures};
          };
        }
      }
      
      # Put 1bp snps second, so that they will overwrite the markup of other variations in the same location
      my @ordered_snps = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [ $_->end == $_->start ? 1 : 0, $_ ] } @$snps;
      
      foreach (@ordered_snps) {
        my $snp_type = 'snp';
        my $variation_name = $_->variation_name;
        my $var_class = $_->can('var_class') ? $_->var_class : $_->can('variation') && $_->variation ? $_->variation->var_class : '';
        my $dbID = $_->dbID;
        my $start = $_->start;
        my $end = $_->end;
        my $alleles = $_->allele_string;
        
        # If gene is reverse strand we need to reverse parts of allele, i.e AGT/- should become TGA/-
        if ($slice_strand < 0) {
          my @al = split(/\//, $alleles);
          
          $alleles = '';
          $alleles .= reverse($_) . '/' for @al;
          $alleles =~ s/\/$//;
        }
      
        # If the variation is on reverse strand, flip the bases
        $alleles =~ tr/ACGTacgt/TGCAtgca/ if $_->strand < 0;
        
        # Use the variation from the underlying slice if we have it.
        my $snp = scalar keys %$u_snps ? $u_snps->{$variation_name} : $_;
        
        # Co-ordinates relative to the sequence - used to mark up the variation's position
        my $s = $start-1;
        my $e = $end-1;
        
        # Co-ordinates relative to the region - used to determine if the variation is an insert or delete
        my $seq_region_start = $snp->seq_region_start;
        my $seq_region_end = $snp->seq_region_end;
        
        # Co-ordinates to be used in link text - will use $start or $seq_region_start depending on line numbering style
        my ($snp_start, $snp_end);
        
        if ($config->{'line_numbering'} eq 'slice') {
          $snp_start = $seq_region_start;
          $snp_end = $seq_region_end;
        } else {
          $snp_start = $start;
          $snp_end = $end;
        }
        
        if ($var_class eq 'in-del') {
          if ($seq_region_start > $seq_region_end) {
            $snp_type = 'insert';
            
            # Neither of the following if statements are guaranteed by $seq_region_start > $seq_region_end.
            # It is possible to have inserts for compara alignments which fall in gaps in the sequence, where $s <= $e,
            # and $snp_start only equals $s if $config->{'line_numbering'} is not 'slice';
            $snp_start = $snp_end if ($snp_start > $snp_end);
            
            if ($s > $e) {
              my $tmp = $s;
              
              $s = $e;
              $e = $tmp;
            }
          } else {
            $snp_type = 'delete';
          }
        }
        
        # Add the sub slice start where necessary - makes the label for the variation show the correct position relative to the sequence
        $snp_start += $config->{'sub_slice_start'}-1 if ($config->{'sub_slice_start'} && $config->{'line_numbering'} ne 'slice');
        
        # Add the chromosome number for the link text if we're doing species comparisons or resequencing.
        $snp_start = $snp->seq_region_name . ":$snp_start" if (scalar keys %$u_snps && $config->{'line_numbering'} eq 'slice');
        
        my $species = $config->{'ref_slice_name'} ? $config->{'species'} : $name;
        my $link_text = qq{ <a href="/$species/Variation/Summary?v=$variation_name;vf=$dbID;vdb=variation">$snp_start:$alleles</a>;};
        
        for ($s..$e) {
          # FIXME: API currently returns variations when the resequenced individuals match the reference
          # This line can be deleted once we get the correct set.
          # Don't mark up variations when the secondary strain is the same as the sequence.
          # $sequence[-1] is the current secondary strain, as it is the last element pushed onto the array
          next if (defined $config->{'match_display'} && $sequence[-1]->[$_]->{'letter'} =~ /[\.~$sequence[0]->[$_]->{'letter'}]/);
          
          $mk->{'variations'}->{$_}->{'type'} = $snp_type;
          $mk->{'variations'}->{$_}->{'alleles'} .= ($mk->{'variations'}->{$_}->{'alleles'} ? '; ' : '') . $alleles;
          
          unshift @{$mk->{'variations'}->{$_}->{'link_text'}}, $link_text if $_ == $s;
        }
      }
    }
    
    # Get exons
    if ($config->{'exon_display'}) {
      my $exontype = $config->{'exon_display'};
      my @exons;
      
      if ($exontype eq 'Ab-initio') {      
        @exons = grep { $_->seq_region_start <= $slice_end && $_->seq_region_end >= $slice_start } map { @{$_->get_all_Exons} } @{$slice->get_all_PredictionTranscripts};
      } elsif ($exontype eq 'vega' || $exontype eq 'est') {
        @exons = map { @{$_->get_all_Exons} } @{$slice->get_all_Genes('', $exontype)};
      } else {
        @exons = map { @{$_->get_all_Exons} } @{$slice->get_all_Genes};
      }
      
      # Values of parameter should not be fwd and rev - this is confusing.
      if ($config->{'exon_ori'} eq 'fwd') {
        @exons = grep { $_->strand > 0 } @exons; # Only exons in same orientation 
      } elsif ($config->{'exon_ori'} eq 'rev') {
        @exons = grep { $_->strand < 0 } @exons; # Only exons in opposite orientation
      }
      
      my @all_exons = map {[ $config->{'comparison'} ? 'compara' : 'other', $_ ]} @exons;
      
      if ($config->{'exon_features'}) {
        push (@all_exons, [ 'gene', $_ ]) for @{$config->{'exon_features'}};
        $config->{'gene_exon_type'} = $config->{'exon_features'}->[0]->isa('Bio::EnsEMBL::Exon') ? 'exons' : 'features';
      }
      
      foreach (@all_exons) {
        my $type = $_->[0];
        my $exon = $_->[1];
        
        next unless $exon->seq_region_start && $exon->seq_region_end;
        
        my $start = $exon->start - ($type eq 'gene' ? $slice_start : 1);
        my $end = $exon->end - ($type eq 'gene' ? $slice_start : 1);
        my $id = $exon->can('stable_id') ? $exon->stable_id : '';
        
        ($start, $end) = ($slice_length - $end - 1, $slice_length - $start - 1) if $slice_strand < 0 && $exon->strand < 0;
        
        next if $end < 0 || $start >= $slice_length;
        
        $start = 0 if $start < 0;
        $end = $slice_length - 1 if $end >= $slice_length;
        
        for ($start..$end) {          
          push (@{$mk->{'exons'}->{$_}->{'type'}}, $type);          
          $mk->{'exons'}->{$_}->{'id'} .= ($mk->{'exons'}->{$_}->{'id'} ? '; ' : '') . $id unless $mk->{'exons'}->{$_}->{'id'} =~ /$id/;
        }
      }
    }
    
    # Get codons
    if ($config->{'codons_display'}) {
      my @transcripts = map { @{$_->get_all_Transcripts} } @{$slice->get_all_Genes};
      
      if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
        foreach my $t (grep { $_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
          next if (!defined $t->translation);
          
          my @codons;
          
          # FIXME: all_end_codon_mappings sometimes returns $_ as undefined for small subslices. This eval stops the error, but the codon will still be missing.
          # Awaiting a fix from the compara team.
          eval {
            @codons = map {{ start => $_->start, end => $_->end, label => 'START' }} @{$t->translation->all_start_codon_mappings || []}; # START codons
            push (@codons, map {{ start => $_->start, end => $_->end, label => 'STOP' }} @{$t->translation->all_end_codon_mappings || []}); # STOP codons
          };
          
          my $id = $t->stable_id;
         
          foreach my $c (@codons) {
            my ($start, $end) = ($c->{'start'}, $c->{'end'});
            
            #FIXME: Temporary hack until compara team can sort this out
            $start = ($start - 2*($slice_start-1));
            $end = ($end - 2*($slice_start-1));
            
            next if ($end < 1 || $start > $slice_length);
            
            $start = 1 unless $start > 0;
            $end = $slice_length unless $end < $slice_length;
            
            for ($start-1..$end-1) {
              $mk->{'codons'}->{$_}->{'label'} .= ($mk->{'codons'}->{$_}->{'label'} ? '; ' : '') . "$c->{'label'}($id)";
            }
          }
        }
      } else { # Normal Slice
        foreach my $t (grep { $_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
          my ($start, $stop, $id) = ($t->coding_region_start, $t->coding_region_end, $t->stable_id);
          
          # START codons
          if ($start > 1) {
            for ($start-1..$start+1) {
              $mk->{'codons'}->{$_}->{'label'} .= ($mk->{'codons'}->{$_}->{'label'} ? '; ' : '') . "START($id)";
            }
          }
          
          # STOP codons
          if ($stop <= $slice_length) {
            for ($stop-3..$stop-1) {
              $mk->{'codons'}->{$_}->{'label'} .= ($mk->{'codons'}->{$_}->{'label'} ? '; ' : '') . "STOP($id)";
            }
          }
        }
      }
    }
    
    push (@markup, $mk);
  }
  
  return (\@sequence, \@markup);
}

sub markup_exons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my $exon_types = {};
  my ($exon, $type, $s, $seq);
  my $i = 0;
  
  my $class = {
    exon0   => 'e0',
    exon1   => 'e1',
    exon2   => 'e2',
    other   => 'eo',
    gene    => 'eg',
    compara => 'e2'
  };
  
  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'exons'}}) {
      $exon = $data->{'exons'}->{$_};
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $exon->{'id'} if $config->{'title_display'};
      
      foreach $type (@{$exon->{'type'}}) {
        $seq->[$_]->{'class'} .= "$class->{$type} " unless $seq->[$_]->{'class'} =~ /\b$class->{$type}\b/;
        $exon_types->{$type} = 1;
      }
    }
    
    $i++;
  }

  if ($config->{'key_template'}) {
    if ($exon_types->{'gene'}) {
      $config->{'key'} .= sprintf ($config->{'key_template'}, $class->{'gene'}, "Location of $config->{'gene_name'} $config->{'gene_exon_type'}");
    }
    
    my $selected;
  
    for my $type ('other', 'compara') {
      if ($exon_types->{$type}) {
        $selected = ucfirst $config->{'exon_display'} unless $config->{'exon_display'} eq 'selected';
        $selected = $config->{'site_type'} if $selected eq 'Core';
        $selected ||= 'selected';
        
        $config->{'key'} .= sprintf ($config->{'key_template'}, $class->{$type}, "Location of $selected exons");
      }
    }
  }
}

sub markup_codons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my ($codons, $class, $seq);
  my $i = 0;

  foreach my $data (@$markup) {
    $codons = 1 if scalar keys %{$data->{'codons'}};
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'codons'}}) {      
      $seq->[$_]->{'class'} .= ($data->{'codons'}->{$_}->{'class'} || 'cu') . " ";
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $data->{'codons'}->{$_}->{'label'} if $config->{'title_display'};
    }
    
    $i++;
  }

  if ($codons && $config->{'key_template'}) {
    # Only used on Gene view, which uses just condonutr colour.
    $config->{'key'} .= sprintf ($config->{'key_template'}, 'cu', 'Location of START/STOP codons');
  }
}

sub markup_variation {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my ($snps, $inserts, $deletes, $seq, $variation, $ambiguity);
  my $i = 0;
  
  my $class = {
    'snp'    => 'sn',
    'insert' => 'si',
    'delete' => 'sd'
  };

  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'variations'}}) {
      $variation = $data->{'variations'}->{$_};
      $ambiguity = ambiguity_code($variation->{'alleles'}) || undef;

      $seq->[$_]->{'letter'} = $ambiguity if $ambiguity;
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $variation->{'alleles'} if $config->{'title_display'};
      $seq->[$_]->{'class'} .= "$class->{$variation->{'type'}} ";
      
      if ($config->{'snp_display'} eq 'snp_link' && $variation->{'link_text'}) {          
        $seq->[$_]->{'post'} = join '', @{$variation->{'link_text'}};
      }

      $snps = 1 if $variation->{'type'} eq 'snp';
      $inserts = 1 if $variation->{'type'} =~ /insert/;
      $deletes = 1 if $variation->{'type'} eq 'delete';
    }
    
    $i++;
  }

  $config->{'key'} .= sprintf ($config->{'key_template'}, $class->{'snp'}, 'Location of SNPs') if $snps;
  $config->{'key'} .= sprintf ($config->{'key_template'}, $class->{'insert'}, 'Location of inserts') if $inserts;
  $config->{'key'} .= sprintf ($config->{'key_template'}, $class->{'delete'}, 'Location of deletes') if $deletes;
}

sub markup_comparisons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;
  
  my $name_length = length ($config->{'ref_slice_name'} || $config->{'species'});
  my $max_length = $name_length;
  my $padding = '';
  my $i = 0;
  my ($species, $length, $length_diff, $pad, $seq, $comparison);
  my $title_check = ($comparison->{'insert'} && $config->{'title_display'});
  
  foreach (@{$config->{'slices'}}) {
    $species = $_->{'name'};
    
    push (@{$config->{'seq_order'}}, $species);
    
    next if $species eq $config->{'species'};
    
    $length = length $species;
    $length_diff = $length - $name_length;

    if ($length > $max_length) {
      $max_length = $length;
      $padding = ' ' x $length_diff;
    }
  }
  
  foreach (@{$config->{'seq_order'}}) {
    $pad = ' ' x ($max_length - length $_);
    $config->{'padded_species'}->{$_} = $_ . $pad;
  }
  
  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'comparisons'}}) {
      $comparison = $data->{'comparisons'}->{$_};
      
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $comparison->{'insert'} if $title_check;
      $seq->[$_]->{'class'} .= "res " if $comparison->{'resequencing'}; 
    }
    
    $i++;
  }
  
  if ($config->{'match_display'}) {
    $config->{'key'} .= sprintf($config->{'key_template'}, 'res', 'Resequencing coverage');
    # Using middle dot to make it easier to see
    $config->{'key'} .= '<p><code>&middot;&nbsp;&nbsp;&nbsp;</code>Basepairs in secondary strains matching the reference strain are replaced with dots</p>';
  }
  
  $config->{'v_space'} = "\n";
}

sub markup_conservation {
  my $self = shift;
  my ($sequence, $config) = @_;

  # Regions where more than 50% of bps match considered "conserved"
  my $cons_threshold = int((scalar(@$sequence) + 1) / 2);
  
  my $conserved = 0;
  
  for my $i (0..$config->{'length'}-1) {
    my %cons;
    map $cons{$_->[$i]->{'letter'}}++, @$sequence;
    
    my $c = join '', grep { $_ !~ /~|[-.N]/ && $cons{$_} > $cons_threshold } keys %cons;
    
    foreach (@$sequence) {
      next unless $_->[$i]->{'letter'} eq $c;
      
      $_->[$i]->{'class'} .= "con ";
      $conserved = 1;
    }
  }
  
  if ($conserved) {
    $config->{'key'} .= sprintf ($config->{'key_template'}, "con", "Location of conserved regions (where >50&#37; of bases in alignments match)");
  }
}

sub markup_line_numbers {
  my $self = shift;
  my ($sequence, $config) = @_;
 
  # Keep track of which element of $sequence we are looking at
  my $n = 0;

  # If we only have only one species, $config->{'seq_order'} won't exist yet (it's created in markup_comparisons)
  $config->{'seq_order'} = [ $config->{'species'} ] unless $config->{'seq_order'};
  
  foreach my $sl (@{$config->{'slices'}}) {
    my @numbering;
    my $slice = $sl->{'slice'};
    my $name = $sl->{'name'};
    my $align_slice = 0;
    my $seq = $sequence->[$n];
    
    if ($config->{'line_numbering'} eq 'slice') {
      my $start_pos = 0;
      
      if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
       $align_slice = 1;
      
        # Get the data for all underlying slices
        foreach (@{$sl->{'underlying_slices'}}) {
          my $ostrand = $_->strand;
          my $sl_start = $_->start;
          my $sl_end = $_->end;
          my $sl_seq_region_name = $_->seq_region_name;
          my $sl_seq = $_->seq;
          
          my $end_pos = $start_pos + length ($sl_seq) - 1;
          
          if ($sl_seq_region_name ne 'GAP') {
            push (@numbering, {
              dir => $ostrand,
              start_pos => $start_pos,
              end_pos  => $end_pos,
              start => $ostrand > 0 ? $sl_start : $sl_end,
              end => $ostrand > 0 ? $sl_end : $sl_start,
              label => $sl_seq_region_name . ':'
            });
            
            # Padding to go before the label
            $config->{'padding'}->{'pre_number'} = length $sl_seq_region_name if length $sl_seq_region_name > $config->{'padding'}->{'pre_number'};
          }
          
          $start_pos += length $sl_seq;
        }
      } else {
        # Get the data for the slice
        my $ostrand = $slice->strand;
        my $slice_start = $slice->start;
        my $slice_end = $slice->end;
        
        @numbering = ({ 
          dir => $ostrand,
          start => $ostrand > 0 ? $slice_start : $slice_end,
          end => $ostrand > 0 ? $slice_end : $slice_start,
          label => $slice->seq_region_name . ':'
        });
      }
    } else {
      # Line numbers are relative to the sequence (start at 1)
      @numbering = ({ 
        dir => 1,  
        start => $config->{'sub_slice_start'} || 1,
        end => $config->{'sub_slice_end'} || $config->{'length'},
        label => ''
      });
    }
    
    my $data = shift @numbering unless ($config->{'numbering'} && !$config->{'numbering'}->[$n]);
    
    my $s = 0;
    my $e = $config->{'display_width'} - 1;
    
    my $row_start = $data->{'start'};
    my ($start, $end);
    
    # One line longer than the sequence so we get the last line's numbers generated in the loop
    my $loop_end = $config->{'length'} + $config->{'display_width'};
    
    while ($e < $loop_end) {
      my $shift = 0; # To check if we've got a new element from @numbering
      
      $start = '';
      $end = '';
      
      # Comparison species
      if ($align_slice) {
        # Build a segment containing the current line of sequence
        my $segment = substr ($slice->{'seq'}, $s, $config->{'display_width'});
        (my $seq_length_seg = $segment) =~ s/\.//g;
        my $seq_length = length $seq_length_seg; # The length of the sequence which does not consist of a .
    
        my $first_bp_pos = 0; # Position of first letter character
        my $last_bp_pos = 0;  # Position of last letter character

        if ($segment =~ /\w/) {
          $segment =~ /(^\W*).*\b(\W*$)/;
          $first_bp_pos = 1 + length $1 unless length ($1) == length ($segment);
          $last_bp_pos = $2 ? length ($segment) - length ($2) : length $segment;
        }
        
        my $old_label = '';
        
        # Get the data from the next slice if we have passed the end of the current one
        while (scalar @numbering && $e >= $numbering[0]->{'start_pos'}) {          
          $old_label ||= $data->{'label'} if ($data->{'end_pos'} > $s); # Only get the old label for the first new slice - the one at the start of the line
          $shift = 1;

          $data = shift @numbering;
          $data->{'old_label'} = $old_label;
          
          # Only set $row_start if the line begins with a .
          # If it does not, the previous slice ends mid-line, so we just carry on with it's start number
          $row_start = $data->{'start'} if $segment =~ /^\./;
        }
        
        if ($seq_length && $last_bp_pos) {
          # This is NOT necessarily the same as $end + $data->{'dir'}, as bits of sequence could be hidden
          (undef, $row_start) = $slice->get_original_seq_region_position($s + $first_bp_pos);
          
          $start = $row_start;

          # For AlignSlice display the position of the last meaningful bp
          (undef, $end) = $slice->get_original_seq_region_position($e + 1 + $last_bp_pos - $config->{'display_width'});
        }

        $s = $e + 1;
      } elsif ($config->{'numbering'}) { # Transcript sequence
        my $seq_length = 0;
        my $segment = '';
        
        # Build a segment containing the current line of sequence        
        for ($s..$e) {
          # Check the array element exists - must be done so we don't create new elements and mess up the padding at the end of the last line
          if ($seq->[$_]) {
            $seq_length++ if $seq->[$_]->{'letter'} =~ /\w/;
            $segment .= $seq->[$_]->{'letter'};
          }
        }
        
        $end = $e < $config->{'length'} ? $row_start + $seq_length - $data->{'dir'} : $data->{'end'};
        
        $start = $row_start if $seq_length;
        
        # If the line starts -- or -= it is at the end of a protein section, so take one off the line number
        $start-- if ($start > $data->{'start'} && $segment =~ /^-\W/);
        
        # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
        $row_start = $end + $data->{'dir'} if $start && $end;
        
        # Remove the line number if the sequence doesn't start at the beginning of the line
        $start = '' if $segment =~ /^\./;
        
        $s = $e + 1;
      } else { # Single species
        $end = $e < $config->{'length'} ? $row_start + ($data->{'dir'} * $config->{'display_width'}) - $data->{'dir'} : $data->{'end'};
        
        $start = $row_start;
                
        # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
        $row_start = $end + $data->{'dir'} if $end;
      }
      
      my $label = ($start && $config->{'comparison'}) ? $data->{'label'} : '';
      my $post_label = ($shift && $label && $data->{'old_label'}) ? $label : '';
      $label = $data->{'old_label'} if $post_label;
      
      push (@{$config->{'line_numbers'}->{$n}}, { start => $start, end => $end, label => $label, post_label => $post_label });

      # Increase padding amount if required
      $config->{'padding'}->{'number'} = length $start if length $start > $config->{'padding'}->{'number'};
      
      $e += $config->{'display_width'};
    }
    
    $n++;
  }
  
  $config->{'padding'}->{'pre_number'}++ if $config->{'padding'}->{'pre_number'}; # Compensate for the : after the label
 
  if ($config->{'line_numbering'} eq 'slice' && $config->{'align'}) {
    $config->{'key'} .= qq{<p>NOTE: For secondary species we display the coordinates of the first and the last mapped (i.e A,T,G,C or N) basepairs of each line</p>};
  }
}

sub build_sequence {
  my $self = shift;
  my ($sequence, $config) = @_;
  
  my $line_numbers = $config->{'line_numbers'};
  my $html; 
  my @output;
  my $s = 0;

  # Temporary patch because Firefox doesn't copy/paste anything but inline styles
  # If we remove this patch, look at version 1.79 for the correct code to revert to
  my $styles = $self->object->species_defs->colour('sequence_markup');
  my %class_to_style = (
    con =>  [ 1,  { 'background-color' => "#$styles->{'SEQ_CONSERVATION'}->{'default'}" } ],
    dif =>  [ 2,  { 'background-color' => "#$styles->{'SEQ_DIFFERENCE'}->{'default'}" } ],
    res =>  [ 3,  { 'color' => "#$styles->{'SEQ_RESEQEUNCING'}->{'default'}" } ],
    e0  =>  [ 4,  { 'color' => "#$styles->{'SEQ_EXON0'}->{'default'}" } ],
    e1  =>  [ 5,  { 'color' => "#$styles->{'SEQ_EXON1'}->{'default'}" } ],
    e2  =>  [ 6,  { 'color' => "#$styles->{'SEQ_EXON2'}->{'default'}" } ],
    eo  =>  [ 7,  { 'background-color' => "#$styles->{'SEQ_EXONOTHER'}->{'default'}" } ],
    eg  =>  [ 8,  { 'color' => "#$styles->{'SEQ_EXONGENE'}->{'default'}", 'font-weight' => "bold" } ],
    c0  =>  [ 9,  { 'background-color' => "#$styles->{'SEQ_CODONC0'}->{'default'}" } ],
    c1  =>  [ 10, { 'background-color' => "#$styles->{'SEQ_CODONC1'}->{'default'}" } ],
    cu  =>  [ 11, { 'background-color' => "#$styles->{'SEQ_CODONUTR'}->{'default'}" } ],
    sn  =>  [ 12, { 'background-color' => "#$styles->{'SEQ_SNP'}->{'default'}" } ],      
    si  =>  [ 13, { 'background-color' => "#$styles->{'SEQ_SNPINSERT'}->{'default'}" } ],
    sd  =>  [ 14, { 'background-color' => "#$styles->{'SEQ_SNPDELETE'}->{'default'}" } ],   
    snt =>  [ 15, { 'background-color' => "#$styles->{'SEQ_SNP_TR'}->{'default'}" } ],
    syn =>  [ 16, { 'background-color' => "#$styles->{'SEQ_SYN'}->{'default'}" } ],
    snu =>  [ 17, { 'background-color' => "#$styles->{'SEQ_SNP_TR_UTR'}->{'default'}" } ],
    siu =>  [ 18, { 'background-color' => "#$styles->{'SEQ_SNPINSERT_TR_UTR'}->{'default'}" } ],
    sdu =>  [ 19, { 'background-color' => "#$styles->{'SEQ_SNPDELETE_TR_UTR'}->{'default'}" } ],
    sf  =>  [ 20, { 'background-color' => "#$styles->{'SEQ_FRAMESHIFT'}->{'default'}" } ],
    aa  =>  [ 21, { 'color' => "#$styles->{'SEQ_AMINOACID'}->{'default'}" } ],
    var =>  [ 22, { 'color' => "#$styles->{'SEQ_MAIN_SNP'}->{'default'}" } ],
    end =>  [ 23, { 'color' => "#$styles->{'SEQ_REGION_CHANGE'}->{'default'}", 'background-color' => "#$styles->{'SEQ_REGION_CHANGE_BG'}->{'default'}" } ],
    bold => [ 24, { 'font-weight' => 'bold' } ]
  );

  foreach my $lines (@$sequence) {
    my ($row, $title, $previous_title, $new_line_title, $class, $previous_class, $new_line_class, $pre, $post);
    my ($count, $i);
    
    foreach my $seq (@$lines) {
      $previous_title = $title;
      $title = $seq->{'title'} ? qq{title="$seq->{'title'}"} : '';
      
      $previous_class = $class;
      
      if ($seq->{'class'}) {
        $class = $seq->{'class'};
        chomp $class;
        
        if ($config->{'maintain_colour'} && $previous_class =~ /\s*(e\w)\s*/ && $class !~ /\s*(e\w)\s*/) {
          $class .= " $1";
        }
      } elsif ($config->{'maintain_colour'} && $previous_class =~ /\s*(e\w)\s*/) {
          $class = $1;
      } else {
        $class = '';
      }

      $post .= $seq->{'post'};
      
      my $style;
      
      if ($class) {
        my %style_hash;
        
        foreach (sort { $class_to_style{$a}->[0] <=> $class_to_style{$b}->[0] } split / /, $class) {
          my $st = $class_to_style{$_}->[1];
          
          map $style_hash{$_} = $st->{$_}, keys %$st;
        }
        
        $style = sprintf 'style="%s"', join ';', map "$_:$style_hash{$_}", keys %style_hash;
      }

      if ($i == 0) {
        $row .= "<span $style $title>";
      } elsif ($class ne $previous_class || $title ne $previous_title) {
        $row .= "</span><span $style $title>";
      }
  
      $row .= $seq->{'letter'};
  
      $count++;
      $i++;
  
      if ($count == $config->{'display_width'} || $i == scalar @$lines) {
        if ($i == $config->{'display_width'}) {
          $row = "$row</span>";
        } else {
          my $new_line_style;
          
          if ($new_line_class eq $class) {
            $new_line_style = $style;
          } elsif ($new_line_class) {
            my %style_hash;
            
            foreach (sort { $class_to_style{$a}->[0] <=> $class_to_style{$b}->[0] } split / /, $new_line_class) {
              my $st = $class_to_style{$_}->[1];
              
              map $style_hash{$_} = $st->{$_}, keys %$st;
            }
            
            $new_line_style = sprintf 'style="%s"', join ';', map "$_:$style_hash{$_}", keys %style_hash;
          }
          
          $row = "<span $new_line_style $new_line_title>$row</span>";
        }
        
        if ($config->{'comparison'}) {
          if (scalar keys %{$config->{'padded_species'}}) {
            $pre = $config->{'padded_species'}->{$config->{'seq_order'}->[$s]} || $config->{'species'};
          } else {
            $pre = $config->{'species'};
          }
          
          $pre .= '  ';
        }
         
        push (@{$output[$s]}, { line => $row, length => $count, pre => $pre, post => $post });
        
        $new_line_class = $class;
        $new_line_title = $title || $previous_title;
        $count = 0;
        $row = '';
        $pre = '';
        $post = '';
      }
    }
    
    $s++;
  }

  my $length = $output[0] ? scalar @{$output[0]} - 1 : 0;
  
  for my $x (0..$length) {
    my $y = 0;
    
    foreach (@output) {
      my $line = $_->[$x]->{'line'};
      my $num = shift @{$line_numbers->{$y}};
      
      if ($config->{'number'}) {
        my $pad1 = ' ' x ($config->{'padding'}->{'pre_number'} - length $num->{'label'});
        my $pad2 = ' ' x ($config->{'padding'}->{'number'} - length $num->{'start'});

        $line = $config->{'h_space'} . sprintf("%6s ", "$pad1$num->{'label'}$pad2$num->{'start'}") . $line;
      }
      
      if ($x == $length && ($config->{'end_number'} || $_->[$x]->{'post'})) {
        $line .= ' ' x ($config->{'display_width'} - $_->[$x]->{'length'});
      }
      
      if ($config->{'end_number'}) {
        my $n = $num->{'post_label'} || $num->{'label'};
        my $pad1 = ' ' x ($config->{'padding'}->{'pre_number'} - length $n);
        my $pad2 = ' ' x ($config->{'padding'}->{'number'} - length $num->{'end'});

        $line .= $config->{'h_space'} . sprintf(" %6s", "$pad1$n$pad2$num->{'end'}");
      }
      
      $line = "$_->[$x]->{'pre'}$line" if $_->[$x]->{'pre'};
      $line .= $_->[$x]->{'post'} if $_->[$x]->{'post'};      
      
      $html .= "$line\n";
      $y++;
    }
    
    $html .= $config->{'v_space'};
  }
  
  $config->{'html_template'} ||= qq{<pre>%s</pre>};  
  $config->{'html_template'} = sprintf($config->{'html_template'}, $html);
  
  return $config->{'html_template'};
}

# When displaying a very large sequence we can break it up into smaller sections and render each of them much more quickly
sub chunked_content {
  my $self = shift;
  my ($total_length, $chunk_length, $base_url) = @_;

  my $object = $self->object;

  my $i = 1;
  my $j = $chunk_length;
  my $end = (int ($total_length / $j)) * $j; # Find the final position covered by regular chunking - we will add the remainer once we get past this point.
  my ($url, $html);

  my $renderer = ($ENV{'ENSEMBL_AJAX_VALUE'} eq 'enabled') ? undef : new EnsEMBL::Web::Document::Renderer::Assembler(session => $object->get_session);

  # The display is split into a managable number of sub slices, which will be processed in parallel by requests
  while ($j <= $total_length) {
    $url = qq{$base_url;subslice_start=$i;subslice_end=$j};

    if ($renderer) {
      map { $url .= ";$_=" . $object->param($_) } $object->param;

      $renderer->print(HTTP::Request->new('GET', $object->species_defs->ENSEMBL_BASE_URL . $url));
    } else {
      $html .= qq{<div class="ajax" title="['$url;$ENV{'QUERY_STRING'}']"></div>};
    }

    last if $j == $total_length;

    $i = $j + 1;
    $j += $chunk_length;

    $j = $total_length if $j >= $end;
  }

  if ($renderer) {
    $renderer->process;
    $html = $renderer->content;
  }

  return $html;
}

1;

