package EnsEMBL::Web::Factory::MultipleLocation;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory::Location;
use EnsEMBL::Web::Proxy::Object;
use Bio::EnsEMBL::Feature;
use POSIX qw(floor ceil);

our @ISA = qw(  EnsEMBL::Web::Factory::Location );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  $self->__set_species(); ## Initialise factory and set master species...
  return $self; 
}

#----------------- Create objects ----------------------------------------------
## Create objects looks for a series of parameters passed to the script:
## (1) Primary slice: c = sr:start:ori; w = width
##                     srr = ?; cr = ?; cl = ?; srs = ?; srn = ?; srl = ?; srw = ?; c.x = ?
## (2) Alternate slices:
##                     s{n} = species; [c{n} = sr:start:ori; w{n};] 
##               -or-  s{n} = species; [sr{n} = sr;]
## OR
##
## (1) Primary slice: gene = gene;
## (2) Alternate slices:
##                     s{n} = species; g{n} = gene; 


sub createObjects { 
  my $self      = shift;    
  $self->get_databases('core','compara');
  my $database  = $self->database('core');
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $database;
  if( $self->param('gene') ) {
    $self->createObjectsGene();
  } else {
    $self->createObjectsLocation();
  }
}

sub new_MultipleLocation {
  my( $self, @locations ) = @_;
  my $T = EnsEMBL::Web::Proxy::Object->new( 'MultipleLocation', \@locations, $self->__data );
  $T->species( $locations[0]->real_species ) if @locations;
  return $T;
}

sub createObjectsGene {
  my $self = shift;
  my @locations = ( $self->_location_from_Gene( $self->param('gene') ) ); ## Assume these are core genes at the moment

  foreach my $par ( $self->param ) {
    if( $par =~ /^s(\d+)$/ ) {
      my $ID = $1;
      my $species = $self->map_alias_to_species( $self->param($par) );
      $self->__set_species( $species );
      $self->databases_species( $species, 'core', 'compara' );
      $locations[$ID] = $self->_location_from_Gene( $self->param("g$ID") );
    }
  }
  my $TO = $self->new_MultipleLocation( grep {$_} @locations );
  foreach my $par ( $self->param ) { 
    $TO->highlights( $self->param($par) ) if $par =~ /^g(\d+|ene)$/;
  }
  $self->DataObjects( $TO );
}

sub _dna_align_feature_adaptor {
  my $self = shift;
  return $self->__data->{'compara_adaptors'}{'dna_align_feature'} ||=
    $self->database('compara')->get_DnaAlignFeatureAdaptor();
}

sub self_compara {
	my $self = shift;
	my $p_sp = $self->{'data'}{'__location'}{'species'};
	my %sp;
	$sp{$p_sp}++;
	foreach my $ip ($self->param) {
		if ($ip =~ /^s(\d+)$/) {
			my $s = $self->param($ip);
			my $s_sp = $self->map_alias_to_species($s);
			$sp{$s_sp}++;
		}
		if ($ip eq 'flip') {
			my $s_sr = $self->param($ip);
			my ($s,$sr) = split /:/, $s_sr;
			next unless $sr;
			my $s_sp = $self->map_alias_to_species($s);
			$sp{$s_sp}++;
		}
	}
	my $sc = (grep {$sp{$_} > 1 } keys %sp) ? 1 : 0;
	return $sc;
}


sub createObjectsLocation {
  my $self = shift;

#show input parameters
#  foreach ($self->param) {	  
#	  warn "$_ = ",$self->param($_),"\n";
#  }

  my $location;
  my $width = 1;
  my @slice_defaults = ();
  if( $self->param( 'u' ) ) {
    my @pars = split( ':', $self->param('u') );
    unshift @pars, $self->species;
    while( my @T = splice( @pars, 0, 5 ) ) {
      push @slice_defaults, \@T;
    } 
  }

  if( my $temp_id = $self->param( 'click.x' ) + $self->param( 'vclick.y' ) ) {
    $location = $self->_location_from_SeqRegion( $self->param( 'seq_region_name' ) );
    if( $location ) {
      $width = $self->param( 'seq_region_width' );
      $location->setCentrePoint(
        floor(
          $self->param( 'seq_region_left' ) +
            ( $temp_id - $self->param( 'click_left' ) + 0.5 ) /
            ( $self->param( 'click_right' ) - $self->param( 'click_left' ) + 1 ) *
            ( $self->param( 'seq_region_right' ) - $self->param( 'seq_region_left' ) + 1 )
        ),
        $width
      );
    }
  } elsif( $temp_id = $self->param('region') ) {
    $location = $self->_location_from_SeqRegion( $temp_id, $self->param('vc_start'), $self->param('vc_end'), 1, 1 );
    $width = $self->param('vc_end') - $self->param('vc_start') + 1;
  } elsif( $self->param('l') =~ /^([-\w\.]+):(-?[\.\w]+)-([\.\w]+)$/ ) {
    my($sr,$start,$end) = ($1,$2,$3);
    $start = $self->evaluate_bp($start);
    $end   = $self->evaluate_bp($end);
      $width = $end - $start + 1;
    $location = $self->_location_from_SeqRegion( $sr,$start,$end,1,1);
  } else {
    my( $seq_region,$cp,$t_strand ) =
      $self->param('c') =~ /^([-\w\.]+):(-?[.\w]+)(:-?1)?$/ ? ($1,$2,$3) : 
        ($slice_defaults[0][0], $slice_defaults[0][1], $slice_defaults[0][2] );
    my $strand = $t_strand =~ /^:?-1$/ ? -1 : 1;
    $cp    = $self->evaluate_bp( $cp );
    $width = defined $self->param('w') ? $self->evaluate_bp( $self->param('w') ) : $slice_defaults[0][3];
    my $start = $cp - ($width-1)/2;
    my $end   = $cp + ($width-1)/2;
    $location = $self->_location_from_SeqRegion( $seq_region, $start, $end, $strand, 1 );
  }
  if( $self->param('id')==0 && $self->param('action') ) {
    my $name   = $location->seq_region_name;
    my $start  = $location->seq_region_start;
    my $end    = $location->seq_region_end;
    my $strand = $location->seq_region_strand;
    my $w      = $end-$start+1;
    my $flag   = 0;
       if( $self->param('action') eq 'left'   ) { $start -= $w/10 * $strand; $end -= $w/10 * $strand; $flag = 1; }
    elsif( $self->param('action') eq 'left2'  ) { $start -= $w/2  * $strand; $end -= $w/2  * $strand; $flag = 1; }
    elsif( $self->param('action') eq 'right'  ) { $start += $w/10 * $strand; $end += $w/10 * $strand; $flag = 1; }
    elsif( $self->param('action') eq 'right2' ) { $start += $w/2  * $strand; $end += $w/2  * $strand; $flag = 1; }
    elsif( $self->param('action') eq 'flip'   ) { $strand = -$strand;             $flag = 1; }
    elsif( $self->param('action') eq 'in'     ) { $start += $w/4;  $end -= $w/4;  $flag = 1; }
    elsif( $self->param('action') eq 'out'    ) { $start -= $w/2;  $end += $w/2;  $flag = 1; }
    if( $flag ) {
      $location = $self->_location_from_SeqRegion( $name, $start, $end, $strand, 1 );
      $width = $end - $start + 1;
    }
  }

  my @locations = ($location);
  my $primary_slice = undef;
  my $dafad         = undef;
  my ($flip_species,$flip_sr) = split /:/, $self->param('flip');
  my $flip        = $self->map_alias_to_species($flip_species);
  my $add_best_to = $flip;
  my $sc = $self->self_compara;
  foreach my $par ( $self->param ) {
    if( $par =~ /^s(\d+)$/ ) {
      my $ID = $1;
	  #don't do anything further with the primary strand in a self-compara
	  next if ($sc && ($self->param("sr$ID")) && ($self->param("sr$ID") eq $self->param('seq_region_name')));
	  #get chr argument for self compara
	  my $chrom = '';
	  if ($self->param("sr$ID")) {
		  warn "1----";
		  $chrom = $self->param("sr$ID");
	  } elsif ($sc) {
		  warn "2----";
		  ($chrom) =  $self->param("c$ID") =~ /^([-\w\.]+):?/;
	  }
#	  warn "CHROM = $chrom";
#	  warn "sc = $sc";
      my $species = $self->map_alias_to_species( $self->param($par) );
	  ## Skip if we've said flip an active species....
	  if ($sc) {
		  if ($flip_sr eq $chrom) {
			  $add_best_to = undef;
			  next;
		  }
      } elsif( $species eq $flip_species ) {
		  $add_best_to = undef;
		  next;
      }
      $self->__set_species( $species );
      $self->databases_species( $species, 'core', 'compara' );
      if( ( $self->param("c$ID") || @slice_defaults ) &&
         !( $self->param('action') eq 'realign' && $self->param('id')==0 )
      ) { ## We have a centre point (and optional width specified);
        my( $seq_region,$cp,$t_strand ) = 
          $self->param("c$ID" ) =~ /^([-\w\.]+):(-?[.\w]+)(:-?1)?$/ ? 
          ($1,$2,$3) : ($slice_defaults[$ID][0], $slice_defaults[$ID][1], $slice_defaults[$ID][2] );
        my $strand = $t_strand =~ /^:?-1$/ ? -1 : 1;
        my $w = defined $self->param("w$ID") ? $self->param("w$ID") :
          ( @slice_defaults ? $slice_defaults[$ID][3] : $width );
        $cp   = $self->evaluate_bp( $cp );
        $w = $self->evaluate_bp( $w );
        my $start = $cp - ($w-1)/2;
        my $end   = $cp + ($w-1)/2;
        if( $self->param('id')==$ID ) {
			warn "**10";
             if( $self->param('action') eq 'left'   ) { $start -= $w/10 * $strand; $end -= $w/10 * $strand; }
          elsif( $self->param('action') eq 'left2'  ) { $start -= $w/2  * $strand; $end -= $w/2  * $strand; }
          elsif( $self->param('action') eq 'right'  ) { $start += $w/10 * $strand; $end += $w/10 * $strand; }
          elsif( $self->param('action') eq 'right2' ) { $start += $w/2  * $strand; $end += $w/2  * $strand; }
          elsif( $self->param('action') eq 'flip'   ) { warn "what!!!!";$strand = -$strand; }
          elsif( $self->param('action') eq 'in'     ) { $start += $w/4;  $end -= $w/4;  }
          elsif( $self->param('action') eq 'out'    ) { $start -= $w/2;  $end += $w/2;  }
        }
        if( $self->param('id')==$ID && $self->param('action') eq 'realign' ) {
          $locations[$ID] = $self->_best_guess( $location->slice, $species, $width, $chrom );
        } else {
          $locations[$ID] = $self->_location_from_SeqRegion( $seq_region, $start, $end, $strand, 1 );
        }
	  } elsif ($self->param("sr$ID")) {
		  #we are working with a self-compara
		  $locations[$ID] = $self->_best_guess( $location->slice, $species, $width, $chrom );
      } else {
        $locations[$ID] = $self->_best_guess( $location->slice, $species, $width, $chrom );
      }
      if( $self->param('action') eq 'primary' && $self->param('id') == $ID ) {
        @locations[$ID,0]=@locations[0,$ID];
      }
    }
  }
  if( $add_best_to ) { ## If we are flipping an inactive species...
    push @locations, $self->_best_guess( $location->slice, $add_best_to, $width, $flip_sr);
  }
  $self->DataObjects( $self->new_MultipleLocation( grep {$_} @locations ) );
}

sub map_alias_to_species {
  my( $self, $name ) = @_;
  my $ESA = $self->species_defs->ENSEMBL_SPECIES_ALIASES;
  my %map = map { lc($_), $ESA->{$_} } keys %$ESA;
  return $map{lc($name)};
}

sub _best_guess {
  my( $self, $slice, $species, $width, $chrom ) = @_;
  ( my $S2 = $species ) =~ s/_/ /g;
  ## foreach my $method ( @{$self->species_defs->COMPARATIVE_METHODS} ) {
  foreach my $method ( qw(BLASTZ_NET TRANSLATED_BLAT) ) {
    my( $seq_region, $cp, $strand );
    eval {
warn ".... ($S2 $method $chrom) ....";
      ( $seq_region, $cp, $strand ) = $self->_dna_align_feature_adaptor->interpolate_best_location( $slice, $S2, $method, $chrom );
warn ".... $seq_region $cp $strand ($S2 $method $chrom) ....";
    };
    if( $seq_region ) {
      warn ">> $method <<";
      my $start = $cp - ($width-1)/2;
      my $end   = $cp + ($width-1)/2;
      $self->__set_species( $species );
      return $self->_location_from_SeqRegion( $seq_region, $start, $end, $strand, 1 );
    }
  }
  return ();
}

1;
