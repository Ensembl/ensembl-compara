=head1 NAME

Bio::Search::HSP::EnsembHSP - Ensembl-specific implementation of Bio::Search::HSP::HSPI

=head1 SYNOPSIS

  use Bio::Search::HSP::EnsemblHSP;
  my $hit = Bio::Search::HSP::EnsemblHSP();

  # more likely
  use Bio::SearchIO;
  use Bio::Search::HSP::HSPFactory;
  my $sio = Bio::SearchIO->new(-format=>'blast', -file=>'report.bla');

  my $class = 'Bio::Search::HSP::EnsemblHSP';
  my $factory =  Bio::Search::HSP::HSPFactory->new(-type=>$class);
  $sio->_eventHandler->register_factory('hsp',$factory);
  
  my $result = $sio->next_result;
  my $hit    = $result->next_hit;
  my $hsp    = $result->next_hsp;

=head1 DESCRIPTION

This object extends Bio::Search::HSP::GenericHSP in several respects:
* Provides ensembl-specific 'species' and 'datatabase' methods,
* Provides '_map' hook to allow mapping of HSP from native database to 
  genomic coordinates (uses Bio::EnsEMBL::Adaptor),
* Inherets from Bio::Root::Storable, allowing results to be saved-to
  and retrieved-from disk,
* Overrides the default Bio::Root::Storable behaviour to store object to 
  database using Bio::EnsEMBL::External::BlastAdaptor.
* Provides methods to allow HSPs to be retrieved by ID

=cut

#======================================================================
# Let the code begin...

package Bio::Search::HSP::EnsemblHSP;

use strict;
#use Data::Dumper qw( Dumper );
use vars qw(@ISA);

use Bio::Root::Storable;
use Bio::Search::HSP::GenericHSP;
use Bio::SeqFeature::Generic;

use Bio::EnsEMBL::SeqFeature;        # Basic
use Bio::EnsEMBL::FeaturePair;       # Comparison
use Bio::EnsEMBL::DnaDnaAlignFeature; # Algnment
use Bio::EnsEMBL::Slice;             # For creating alignments
use Bio::EnsEMBL::CoordSystem;       # For retrieving slices

@ISA = qw( Bio::Search::HSP::GenericHSP 
	   Bio::Root::Storable );

#----------------------------------------------------------------------

=head2 new

  Arg [1]   : -core_adaptor  => Bio::EnsEMBL::Adaptor
  Function  : Builds a new Bio::Search::HSP::EnsemblHSP object
  Returntype: Bio::Search::HSP::EnsemblHSP
  Exceptions: 
  Caller    : 
  Example   : $hit = Bio::Search::HSP::EnsemblHSP->new()

=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  $self->_initialise_storable(@args);

  my( $blast_adaptor, $core_adaptor ) 
    = $self->_rearrange([qw(BLAST_ADAPTOR CORE_ADAPTOR)]);

  $blast_adaptor && $self->blast_adaptor( $blast_adaptor );
  $core_adaptor  && $self->core_adaptor(  $core_adaptor  );

  return $self;
}

#----------------------------------------------------------------------

=head2 blast_adaptor

  Arg [1]   : 
  Function  : DEPRECATED. Use adaptor method instead
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 
  Example   : 
=cut
sub blast_adaptor {
  my $self = shift;
  my $caller = join( ', ', (caller(0))[1..2] );
  $self->warn( "Deprecated: use adaptor method instead: $caller" ); 
  return $self->adaptor(@_);
}

#----------------------------------------------------------------------

=head2 core_adaptor

  Arg [1]   : Bio::EnsEMBL::Adaptor optional
  Function  : Accessor for the core database adaptor
  Returntype: Bio::EnsEMBL::Adaptor
  Exceptions: 
  Caller    : 
  Example   : $hsp->blast_adaptor( $core_adpt )
  Example   : $core_adpt = $hsp->blast_adaptor()

=cut

sub core_adaptor {
  my $key = '__core_adaptor'; # Don't serialise
  my $self = shift;
  if( @_ ){ $self->{$key} = shift }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 DEPRECATED

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub database_name {
  my $self = shift;
  $self->warn( "DEPRECATED - " . join( ', ', (caller(0))[3,1,2] ) );
  return;
}
sub species {
  my $self = shift;
  $self->warn( "DEPRECATED - " . join( ', ', (caller(0))[3,1,2] ) );
  return;
}
sub database {
  my $self = shift;
  $self->warn( "DEPRECATED - " . join( ', ', (caller(0))[3,1,2] ) );
  return;
}

#----------------------------------------------------------------------

=head2 _map

  Arg [1]   : string $database_type
              the type of database as configured in DEFAULTS.ini, e.g;
              LATESTGP, CDNA_SNAP etc.
  Function  : Uses Bio::EnsEMBL::Adaptor to map database-native alignment 
              locations to genomic locations
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _map {
  my $self = shift;
  my $database_type = shift;
  my $DBAdaptor = $self->core_adaptor || 
    ( $self->warn( "Core adaptor not set, can't map!" ) and return );

  my $hit   = $self->hit;
  my $query = $self->query;

  # Get sequence type (DNA/CDNA etc) and id type (CONTIG/SNAP etc) from:
  # A. from the Ensembl-style sequence description of the hit (preferred),
  # B. From the sequence ID, e.g. >chr:1 (mainly for BLAT),
  # C. From the provided $database_name
  # D. Nothing appropriate. Cannot map.

  my $hit_name = $hit->seq_id;
  my( $hit_seqtype, $hit_idtype, $hit_start_offset );

  if( my $desc = $hit->seqdesc ){ # Examine for type A
    my( $type_str, $slice_name, $extra ) = split( /\s+/, $desc );
    ( $hit_seqtype, $hit_idtype ) = split( /:/, $type_str );
  }

  if( ! $hit_idtype and $hit_name=~/:/){ # Examine for type B
    my @bits = split( /[:]/, $hit_name );
    $bits[0] =~ s/.*\///; # Strip any path from FASTA ID (BLAT)
    if( @bits == 4 ){
      # Case 1 - seqtype:idtype:id:start-end
      ( $hit_seqtype, $hit_idtype, $hit_name, $hit_start_offset ) = @bits;
      ( $hit_start_offset ) = split( '-', $hit_start_offset ); # Discard 'end'
    } elsif( @bits == 3 and $bits[-1]=~/-/ ){
      # Case 2 - seqtype:id:start-end
      ( $hit_idtype, $hit_name, $hit_start_offset ) = @bits;
      ( $hit_start_offset ) = split( '-', $hit_start_offset ); # Discard 'end'
    } elsif( @bits == 3 ){
      # Case 3 - seqtype:idtype:id
      ( $hit_seqtype, $hit_idtype, $hit_name ) = @bits;
    } elsif( @bits == 2 and $bits[-1]=~/-/ ){
      # Case 4 - id:start-end
      ( $hit_name, $hit_start_offset ) = @bits;
      ( $hit_start_offset ) = split( '-', $hit_start_offset ); # Discard 'end'
    } else{
      # Case 5 - idtype:id
      ( $hit_idtype, $hit_name ) = @bits;
    }
    # Exceptions
    if( $hit_idtype =~ /^chr/i ){ $hit_idtype='chromosome' }
    $hit_seqtype ||= 'dna';
  }
  if( ! $hit_idtype ){ # Default to type C
    ( $hit_seqtype, $hit_idtype ) = split( "_", $database_type, 2 );
    # Exceptions
    if( $hit_seqtype =~ /^LATESTGP/i ){ $hit_seqtype = 'dna' }
  }

  # Populate hit meta-hash
  my %dbseq_meta;
  $dbseq_meta{name}    = $hit_name;
  $dbseq_meta{type}    = lc( $hit_seqtype );
  $dbseq_meta{subtype} = lc( $hit_idtype  );
  $dbseq_meta{offset}  = ( $hit_start_offset || 1 ) - 1;

  my( @chr_coords, @ctg_coords );
  my( $chr_name, $ctg_name );
  my $q_strand = $self->query->strand || 1;
  my $h_strand = $self->hit->strand   || 1;
  my $g_strand = 0;

  # CDNA || PEP || RNA
  if( $dbseq_meta{type} eq 'cdna' or $dbseq_meta{type} eq 'ncrna' or
      $dbseq_meta{type} eq 'pep' ){

    my $transcript;

    # Look for Ensembl gene first
    my $ta = $DBAdaptor->get_TranscriptAdaptor;
    my $fetch_method = ( $dbseq_meta{type} eq 'pep' ?
                         'fetch_by_translation_stable_id' :
                         'fetch_by_stable_id' );
    $transcript = $ta->$fetch_method( $dbseq_meta{name} );
    
    if( ! $transcript ){ # ab-initio gene ?
      my $ta = $DBAdaptor->get_PredictionTranscriptAdaptor;
      $transcript = $ta->fetch_by_stable_id( $dbseq_meta{name} );
    }

    $transcript or
      warn("cannot fetch translation: $dbseq_meta{name}") && return;

    # Map hit into Coordinate objects for each defined coordinate system.
    # TODO: use slice_name instead once problems resolved
    my $mapper = $dbseq_meta{type} eq 'pep' ? 'pep2genomic' : 'cdna2genomic';

#    foreach my $system( keys %HSP_LOCATIONS ){
#      my $ttranscript = $transcript->transform($system);
#      if( ! $ttranscript ){ $HSP_LOCATIONS{$system} = ['AMBIGUOUS']; next } 

    my @coords = ( sort{ $a->start <=> $b->start }
                   grep{ ! $_->isa('Bio::EnsEMBL::Mapper::Gap') }
                   $transcript->$mapper($hit->start,$hit->end) );
    my @cigars;
    for( my $i = 0; $i<@coords; $i++ ){ # Build cigar string
      my $this = $coords[$i];
      push @cigars, ( $this->end - $this->start + 1 ) . 'M';
      my $next = $coords[$i+1] || last;
      push @cigars, ( $next->start - $this->end - 1 ) . 'I';
    }

    #warn( "T_STRAND: $system ", $ttranscript->strand );
    my $t_strand = $h_strand * $q_strand * $transcript->strand;
    if( $coords[0]->strand  < 1 ){ @cigars = reverse @cigars }
    my $cigar = join '', @cigars;
    my $slice = Bio::EnsEMBL::Slice->new(
      -coord_system    => $transcript->slice->coord_system,
      -seq_region_name => $transcript->seq_region_name,
      -start        => $coords[0]->start,
      -end          => $coords[-1]->end,
      -strand       => $t_strand,
      -adaptor      => $DBAdaptor->get_SliceAdaptor
    );
    $self->genomic_hit( $self->_build_feature($slice,$cigar) );
  }

  # DNAFEATURE
  elsif($dbseq_meta{type} eq "dnafeature" ){
    my $feat_adapt = $DBAdaptor->get_DnaAlignFeatureAdaptor;
    my @feats = @{$feat_adapt->fetch_all_by_hit_name($dbseq_meta{name}) };
    if( my $test = $dbseq_meta{subtype} ){
      @feats = grep{$_->analysis->logic_name =~ /$test/i } @feats;
    }
    @feats || last;
    
    # Transform all feats into top level so we can ignore 'stickyness'
    @feats = map{ $_->transform('toplevel') } @feats;
    @feats = sort{$a->hstart <=> $b->hstart} @feats;

    # Ensure feats belong to the same 'mapping', w.r.t the first feat
    @feats = grep{ 
      $_->analysis->logic_name eq $feats[0]->analysis->logic_name and
      $_->seq_region_name eq $feats[0]->seq_region_name and
      $_->strand eq $feats[0]->strand and
      $_->hstrand eq $feats[0]->hstrand
    } @feats;
    @feats || return;

    # Build 'broken features' into single feat
    my $h_start = $self->hstart;
    my $h_end   = $self->hend;
    my $f_ori   = $feats[0]->strand * $feats[0]->hstrand;
    my( $map_start, $map_end, $cigar ) = (0,0,'');
    foreach my $feat( @feats ){
      my $f_start = $feat->hstart;
      my $f_end   = $feat->hend;
      my $g_start = $feat->start;
      my $g_end   = $feat->end;

      # Check that feat overlaps with blast hit
      if( $f_end < $h_start or $f_start > $h_end ){ next }

      # If blast hit starts inside feature
      if( $h_start > $f_start ){
        $g_start += ( $h_start - $f_start );
        $f_start = $h_start;
      }
      # If blast hit ends inside feature
      if( $f_end > $h_end ){
        $g_end -= ( $f_end - $h_end );
        $f_end = $h_end;
      }

      my $M = $g_end - $g_start + 1; # Matching bases
      my $I = 0;
      if( $map_start ){
        $I = $f_ori>0 ? ($g_start-$map_end-1) : ($map_start-$g_end-1);
      }

      if( ! $map_start or $g_start < $map_start ){ $map_start = $g_start }
      if( ! $map_end   or $g_end   > $map_end   ){ $map_end   = $g_end   }
      
      $cigar .= $I ? $I.'I' : '';
      $cigar .= $M ? $M.'M' : '';
    }
    if( ! $map_start or ! $map_end ){ next } # Skip missed aligns
    # Create a slice
    my $t_strand = $h_strand * $q_strand * $f_ori;
#    my $hit_offset = ( $hit->start - $feat->hstart );
#    warn( "--> ", $feat->hstart,"-",$feat->hend  );
    my $slice = Bio::EnsEMBL::Slice->new
      ( -coord_system    => $feats[0]->slice->coord_system,
        -seq_region_name => $feats[0]->seq_region_name,
        -start           => $map_start,
        -end             => $map_end,
        -strand          => $t_strand,
        -adaptor         => $DBAdaptor->get_SliceAdaptor );

    $self->genomic_hit( $self->_build_feature($slice,$cigar) );
  }

  # MARKERFEATURE
  elsif($dbseq_meta{type} eq "markerfeature" ){

    # Fetch marker feats from database
    my $mark_adapt = $DBAdaptor->get_MarkerAdaptor;
    my @markers = @{$mark_adapt->fetch_all_by_synonym($dbseq_meta{name})};
    my $feat_adapt = $DBAdaptor->get_MarkerFeatureAdaptor;
    my @feats = map{@{$feat_adapt->fetch_all_by_Marker($_)}} @markers;
    if( my $test = $dbseq_meta{subtype} ){
      @feats = grep{$_->analysis->logic_name =~ /$test/i } @feats;
    }
    @feats || last;

    # Assume one marker only. Create the slice
    my $g_start = $feats[0]->start + $hit->start - 1;
    my $slice = Bio::EnsEMBL::Slice->new
      ( -coord_system    => $feats[0]->slice->coord_system,
        -seq_region_name => $feats[0]->seq_region_name,
        -start           => $g_start,
        -end             => $g_start + $hit->length,
        -strand          => 1,
        -adaptor         => $DBAdaptor->get_SliceAdaptor );
    my $cigar = $hit->length . 'M'; 
    $self->genomic_hit( $self->_build_feature($slice,$cigar) );
  }

  # DNA || DNA_RM
  else{
    my $coord_system_name = $dbseq_meta{subtype} || 'toplevel';
    my $seq_name          = $dbseq_meta{name};
    my $start             = $hit->start + ( $dbseq_meta{offset} || 0 );
    my $end               = $hit->end   + ( $dbseq_meta{offset} || 0 );
 
    my $SlAdaptor = $DBAdaptor->get_SliceAdaptor;
    my $Slice     = $SlAdaptor->fetch_by_region
      ( $coord_system_name, $seq_name, $start, $end, $hit->strand );
    $Slice or warn( "Cannot fetch_by_region $seq_name" ) && last;

    # TODO: incorperate built-in cigar string
    my $cigar    = ( $end - $start + 1 ) . 'M';
    my $Feature = $self->_build_feature($Slice,$cigar);
    $self->genomic_hit( $Feature );
  }

  return 1;
}

#----------------------------------------------------------------------

=head2 _build_feature

  Arg [1]   : Slice corresponding to alignment region
  Arg [2]   : Cigar string describing alignment within region
  Function  : Builds an Bio::EnsEMBL::BaseAlignFeature object 
              from Slice and cigar
  Returntype: Bio::EnsEMBL::BaseAlignFeature
  Exceptions:
  Caller    : _map
  Example   : my $sf = $self->_build_seq_feature( $slice,'80M' )

=cut

sub _build_feature {
  my $self = shift;
  my $slice = shift || $self->throw( "Need a feature Slice" );
  my $cigar = shift || $self->throw( "Need a cigar string" );

  my $qry = $self->query;
  my $hit = $self->hit;
  my $align = Bio::EnsEMBL::DnaDnaAlignFeature->new
    (  -hseqname  => $qry->seq_id,
       -hstart    => $qry->start,
       -hend      => $qry->end,
       -hstrand   => $qry->strand,
       -seqname   => $slice->seq_region_name,
       -start     => 1,
       -end       => $slice->length,
       -strand    => 1,
#       -start     => $slice->start,
#       -end       => $slice->end,
#       -strand    => $slice->strand,
       -slice     => $slice,
       -cigar_string => $cigar );
  $align->score( $self->score );
  $align->percent_id( $self->percent_identity );
  $align->p_value( $self->pvalue );
  return $align;
}


#----------------------------------------------------------------------

=head2 percent_identity

  Arg [1]   : none
  Function  : Rounds SUPER::percent_identity to 2dp
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub percent_identity{
  my $self = shift;
  my $pct_id = $self->SUPER::percent_identity(@_);
  return defined $pct_id ? sprintf( "%0.2f", $pct_id ) : undef;

}
#----------------------------------------------------------------------

=head2 genomic_hit

  Arg [1]   : [optional] Coordiate system name (defaults to toplevel) OR
              [optional] Bio::EnsEMBL::Feature
  Function  : Get/set accessor for ensembl alignment feature
  Returntype: Bio::EnsEMBL::BaseAlignFeature or undef
  Exceptions:
  Caller    :
  Example   : $chr = $hsp->genomic_hit->seqname('chromosome')

=cut

sub genomic_hit {
  my $self    = shift;
  my $csname;
  # warn caller();
  # warn "@{[keys %$self]}";
  if( @_ ){
    my $thingy = shift;
    # warn $thingy;
    if( $thingy && $thingy->isa('Bio::EnsEMBL::Feature') ){ # Setter
     #  $self->{genomicNEW} ++; # Flag as new-style. Remove after 23.1 release
      my $Feature = $thingy;
      $csname = $Feature->coord_system_name;
      my $DBAdaptor = $self->core_adaptor;
      my $CSAdaptor = $DBAdaptor->get_CoordSystemAdaptor;
      # Transform feature for each coordinate system
      my @transformedFeatures;
      foreach my $CoordSystem( @{$CSAdaptor->fetch_all} ){
        my $cs = $CoordSystem->name;
        my $csFeature   = $Feature->transform($cs) || next;

        # Store in array temporarily so can remove adaptors once all transforms 
        # are done. Don't remove them here because the csFeature and Feature
        # may be sharing a slice
        push @transformedFeatures,$csFeature;

        # Update self
        $self->{"_genomic_hit_$cs"} = $csFeature;

        # Store in the first coord_system that the feature maps to
        # (this should be the highest coord_system - i.e chr, or scaffold or
        # something).
        $self->{"_genomic_hit"} = $csFeature unless $self->{'_genomic_hit'};
      }
      foreach my $csFeature (@transformedFeatures) {
        # Remove adaptors for storability
        $csFeature->adaptor(undef);
        $csFeature->slice->adaptor(undef);
        $csFeature->slice->coord_system->adaptor(undef);
      }
    } else{
      $csname = $thingy;
    }
  }
    
 # if( ! $self->{genomicNEW} ){ # Remap old genomic hit. Remove after 23.1.
 #   my $gh = $self->{"_genomic_hit"} || return;
 #   my $SlAdaptor = $self->core_adaptor->get_SliceAdaptor;
 #   $gh->slice( $SlAdaptor->fetch_by_region('toplevel',$gh->seqname) );
 #   return $self->genomic_hit( $gh );
 # }

  if( $csname ){ return $self->{"_genomic_hit_$csname"} }
  return $self->{"_genomic_hit"};

}


=head2 contig_hit (rename to seqlevel hit?)

  Arg [1]   : [optional] Bio::EnsEMBL::Feature
  Function  : Get/set accessor for ensembl seqlevel alignment feature
  Returntype: Bio::EnsEMBL::Feature
  Exceptions:
  Caller    :
  Example   : $contig = $hsp->contig_hit->seqname()

=cut

sub contig_hit {
  my $caller = join(', ', (caller(0))[0..2] );
  warn( "DEPRECATED use genomic_hit('contig'): $caller\n" );
  my $self = shift;
  return $self->genomic_hit('contig');
}

=head2 ens_genomic_align

  Arg [1]   : [optional] Bio::EnsEMBL::Feature
  Function  : DEPRECATED: use genomic_hit instead
  Returntype: Bio::EnsEMBL::Feature
  Exceptions:
  Caller    : ContigView
  Example   :

=cut

sub ens_genomic_align {
  my $caller = join(', ', (caller(0))[0..2] );
  warn( "DEPRECATED use genomic_hit: $caller\n" );
  my( $self ) = shift;
  return $self->genomic_hit( @_ );
}

#----------------------------------------------------------------------

=head2 token

  Arg [1]   : $token string optional
  Function  : Accessor for 'storable' token. Implementation may change.
  Returntype: $token string
  Exceptions: 
  Caller    : 
  Example   : $hsp_token = $hsp->token()

=cut

sub token{
  my $self = shift;
  my $token = shift;
  if( $token ){ $self->{_statefile} = $token }
  return $self->{_statefile};
}

#----------------------------------------------------------------------

=head2 group_ticket

  Arg [1]   : none
  Function  : Accessor for EnsemblBlastMulti ticket. Implementation may change.
  Returntype: scalar string
  Exceptions: 
  Caller    : Set by EnsemblResult _map method. Got by whoever.
  Example   : $ticket = $hsp->group_ticket()

=cut

sub group_ticket{
  my $key = '_group_ticket';
  my $self = shift;
  if( @_ ){ $self->{$key} = shift }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 use_date

  Arg [1]   : scalar string
  Function  : Sets the adaptor 'use_date', used to set the DB table to which 
              hsps and hits are written to 
  Returntype: scalar string
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub use_date {
  my $key = '_use_date';
  my $self = shift;
  if( @_ ){ $self->{$key} = shift }
  return $self->{$key};
}

#======================================================================
# Shameless copy from BioPerl 1.3. Remove once 1.4 is released
=head2 cigar_string

  Name:     cigar_string
  Usage:    $cigar_string = $hsp->cigar_string
  Function: Generate and return cigar string for this HSP alignment
  Args:     No input needed
  Return:   a cigar string

=cut


sub cigar_string {
    my ($self, $arg) = @_;
    $self->warn("this is not a setter") if(defined $arg);

    unless(defined $self->{_cigar_string}){ # generate cigar string
        my $cigar_string = $self->generate_cigar_string($self->query_string, $self->hit_string);
        $self->{_cigar_string} = $cigar_string;
    } # end of unless

    return $self->{_cigar_string};
}

=head2 generate_cigar_string

  Name:     generate_cigar_string
  Usage:    my $cigar_string = Bio::Search::HSP::GenericHSP::generate_cigar_string ($qstr, $hstr);
  Function: generate cigar string from a simple sequence of alignment.
  Args:     the string of query and subject
  Return:   cigar string

=cut

sub generate_cigar_string {
  my $GAP_SYMBOL = '-';
    my ($self, $qstr, $hstr) = @_;
    my @qchars = split //, $qstr;
    my @hchars = split //, $hstr;

    unless(scalar(@qchars) == scalar(@hchars)){
        $self->throw("two sequences are not equal in lengths");
    }

    $self->{_count_for_cigar_string} = 0;
    $self->{_state_for_cigar_string} = 'M';

    my $cigar_string = '';
    for(my $i=0; $i <= $#qchars; $i++){
        my $qchar = $qchars[$i];
        my $hchar = $hchars[$i];
        if($qchar ne $GAP_SYMBOL && $hchar ne $GAP_SYMBOL){ # Match
            $cigar_string .= $self->_sub_cigar_string('M');
        }elsif($qchar eq $GAP_SYMBOL){ # Deletion
            $cigar_string .= $self->_sub_cigar_string('D');
        }elsif($hchar eq $GAP_SYMBOL){ # Insertion
            $cigar_string .= $self->_sub_cigar_string('I');
        }else{
            $self->throw("Impossible state that 2 gaps on each seq aligned");
        }
    }
    $cigar_string .= $self->_sub_cigar_string('X'); # not forget the tail.
    return $cigar_string;
}

# an internal method to help generate cigar string

sub _sub_cigar_string {
    my ($self, $new_state) = @_;

    my $sub_cigar_string = '';
    if($self->{_state_for_cigar_string} eq $new_state){
        $self->{_count_for_cigar_string} += 1; # Remain the state and increase the counter
    }else{
        $sub_cigar_string .= $self->{_count_for_cigar_string}
            unless $self->{_count_for_cigar_string} == 1;
        $sub_cigar_string .= $self->{_state_for_cigar_string};
        $self->{_count_for_cigar_string} = 1;
        $self->{_state_for_cigar_string} = $new_state;
    }
    return $sub_cigar_string;
}

#======================================================================
1;
