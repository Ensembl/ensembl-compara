=head1 NAME

Bio::EnsEMBL::GlyphSet::base_composition -
Glyphset to display base composition and ethnicities of variations

=head1 DESCRIPTION

This glyphset draws 2 sets of histograms giving you detailed information about
genomic variations. The upper histograms show alleles found, the lower one the
ethnicities of the reads involved. The zmenu holds additional information on
frequencies. All data are retrieved from the Glovar database.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::base_composition;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

=head2 my_label

  Arg[1]      : none
  Example     : my $label = $self->my_label;
  Description : returns the label for the track (displayed track name)
  Return type : String - track label
  Exceptions  : none
  Caller      : $self->init_label()

=cut

sub my_label { return "Base Composition"};

=head2 features

  Arg[1]      : none 
  Example     : my $f = $self->features;
  Description : this function does the data fetching from the Glovar database
  Return type : listref of Bio::EnsEMBL::ExternalData::Glovar::BaseComposition
                objects
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub features {
    my $self = shift;
    my @bases = @{$self->{'container'}->get_all_ExternalLiteFeatures('GlovarBaseComp')};
    return \@bases;
}

=head2 zmenu

  Arg[1]      : a Bio::EnsEMBL::ExternalData::Glovar::BaseComposition object
  Example     : my $zmenu = $self->zmenu($feature);
  Description : creates the zmenu (context menu) for the glyphset. Returns a
                hashref describing the zmenu entries and properties
  Return type : hashref
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub zmenu {
    my ($self, $f ) = @_;
    my $chr_start = $f->start() + $self->{'container'}->chr_start() - 1;
    my (@c, $total, $key);
    my @a = qw(A C G T);
    foreach (@a) {
        push @c, [ $_, $f->alleles->{$_} ];
        $total += $f->alleles->{$_};
    }
    my %zmenu = (
        'caption'              => "base composition",
	"01:bp: $chr_start"    => '',
        "02:genomic base: ".$f->genomic_base => '',
    );
    my $i = 10;
    foreach (@c) {
	$zmenu{"$i:".$_->[0].": ".$_->[1]." (".int(100*$_->[1]/$total)."%)"} = '' if $_->[1];
        $i++;
    }
    foreach (qw(Caucasian Asian African-American unknown)) {
        $zmenu{"$i:$_: ".$f->ethnicity->{$_}} = '' if $f->ethnicity->{$_};
        $i++;
    }
    return \%zmenu;
}

=head2 _init

  Arg[1]      : none
  Example     : 
  Description : main function of the glyphset. Gets the data, reads the config
                and puts everything together for render() to draw it
  Return type : none
  Exceptions  : none
  Caller      : Sanger::Graphics::DrawableContainer::new()

=cut

sub _init {
    my ($self) = @_;
    my $type = $self->check();
    return unless defined $type;
    
    my $VirtualContig   = $self->{'container'};
    my $Config          = $self->{'config'};
    my $strand          = $self->strand();
    my $strand_flag     = $Config->get($type, 'str');
    my $BUMP_WIDTH      = $Config->get($type, 'bump_width');
       $BUMP_WIDTH      = 1 unless defined $BUMP_WIDTH;
    my $im_width        = $Config->image_width();
    my $colours         = $Config->get($type, 'colours');
    my $flag = 1;

    ## If only displaying on one strand skip IF not on right strand....
    return if( $strand_flag eq 'r' && $strand != -1 ||
               $strand_flag eq 'f' && $strand != 1 );

    # Get information about the VC - length, and whether or not to
    # display track/navigation
    my $vc_length      = $VirtualContig->length( );
    my $max_length     = $Config->get( $type, 'threshold' ) || 200000000;
    my $navigation     = $Config->get( $type, 'navigation' ) || 'on';
    my $max_length_nav = $Config->get( $type, 'navigation_threshold' ) || 15000000;

    ## VC too long to display featues dump an error message
    if( $vc_length > $max_length *1010 ) {
        $self->errorTrack( $self->my_label." only displayed for less than $max_length Kb.");
        return;
    }

    ## Decide whether we are going to include navigation (independent of switch) 
    $navigation = ($navigation eq 'on') && ($vc_length <= $max_length_nav *1010);
    
    ## Get information about bp/pixels
    my $pix_per_bp = $Config->transform()->{'scalex'};
    my $bitmap_length = int($VirtualContig->length * $pix_per_bp);
    my ($w, $th) = $Config->texthelper()->px2bp('Tiny');
    my $bp_textwidth = $w * 1.1; # add 10% for scaling text

    my $h = 93;
    my $ih = 36;
    my $sp = 5;
    my $isp = 9;

    my $features = $self->features();
    unless(ref($features)eq'ARRAY') {
        return;
    }

    foreach my $f ( @{$features} ) {
        ## Check strand for display ##
        next if( $strand_flag eq 'b' && $strand != $f->strand );
        ## Check start are not outside VC.... ##
        my $start = $f->start();
        next if $start>$vc_length; ## Skip if totally outside VC
        $start = 1 if $start < 1;
        ## Check end are not outside VC.... ##
        my $end = $f->end();
        next if $end<1;            ## Skip if totally outside VC
        $end = $vc_length if $end>$vc_length;
        
        ## sort alleles to get genomic base first
        my $ga;
        $ga->{$f->genomic_base} = 1;
        my @alleles = sort { $ga->{$a} <=> $ga->{$b} } qw(T A G C);
        
        ## count non-genomic alleles
        my $num;
        foreach (@alleles) {
            $num++ if ($f->alleles->{$_});
        }
        $num--;

        ## count ethnicities
        my $ne;
        my @ethni = qw(unknown Caucasian Asian African-American);
        foreach (@ethni) {
            $ne++ if ($f->ethnicity->{$_});
        }
        
        ## variation bases
        $flag = 0;
        my $i;
        my $composite = new Sanger::Graphics::Glyph::Composite();
        foreach (@alleles) {
            next if ((!$f->alleles->{$_}) || ($_ eq $f->genomic_base));
            $composite->push( new Sanger::Graphics::Glyph::Rect({
                'x'          => $start-1,
                'y'          => $sp + $i*$ih/$num,
                'width'      => $end - $start + 1,
                'height'     => $ih/$num,
                "colour"     => $colours->{$_},
            }) );
            if ($bp_textwidth < ($end - $start + 1)) {
                $composite->push(new Sanger::Graphics::Glyph::Text({
                    'x'      => ($end + $start - 1 - $bp_textwidth)/2,
                    'y'      => $sp + $ih*$i/$num + ($ih/$num - $th)/2,
                    'width'  => $bp_textwidth,
                    'height' => $th,
                    'font'   => 'Tiny',
                    'colour' => 'black',
                    'text'   => $_,
                }));
            }
            $i++;
        }

        ## genomic base
        $composite->push( new Sanger::Graphics::Glyph::Rect({
            'x'          => $start-1,
            'y'          => $sp + $ih,
            'width'      => $end - $start + 1,
            'height'     => $isp,
            "colour"     => $colours->{$f->genomic_base},
        }) );
        if ($bp_textwidth < ($end - $start + 1)) {
            $composite->push(new Sanger::Graphics::Glyph::Text({
                'x'         => ($end + $start - 1 - $bp_textwidth)/2,
                'y'         => $sp + $ih + ($isp-$th)/2,
                'width'     => $bp_textwidth,
                'height'    => $th,
                'font'      => 'Tiny',
                'colour'    => 'blaock',
                'text'      => $f->genomic_base,
            }));
        }

        ## ethnicities
        my $j;
        foreach (@ethni) {
            next unless ($f->ethnicity->{$_} && $num);
            $composite->push( new Sanger::Graphics::Glyph::Rect({
                'x'          => $start-1,
                'y'          => $sp + $ih + $isp + $j*$ih/$ne,
                'width'      => $end - $start + 1,
                'height'     => $ih/$ne,
                "colour"     => $colours->{$_},
            }) );
            $j++;
        }

        ## borders (if zoomed in)
        if (($vc_length < ($max_length*1010/2)) && $num) {
            $composite->push(new Sanger::Graphics::Glyph::Rect({
                'x'         => $start-1,
                'y'         => $sp,
                'width'     => 0,
                'height'    => $ih,
                'colour'    => 'black',
            }));
            $composite->push(new Sanger::Graphics::Glyph::Rect({
                'x'         => $end,
                'y'         => $sp,
                'width'     => 0,
                'height'    => $ih,
                'colour'    => 'black',
            }));
            $composite->push(new Sanger::Graphics::Glyph::Rect({
                'x'          => $start-1,
                'y'          => $sp,
                'width'      => $end - $start + 1,
                'height'     => 0,
                "colour"     => 'black',
            }));
            $composite->push(new Sanger::Graphics::Glyph::Rect({
                'x'         => $start-1,
                'y'         => $sp + $ih + $isp,
                'width'     => 0,
                'height'    => $ih,
                'colour'    => 'black',
            }));
            $composite->push(new Sanger::Graphics::Glyph::Rect({
                'x'         => $end,
                'y'         => $sp + $ih + $isp,
                'width'     => 0,
                'height'    => $ih,
                'colour'    => 'black',
            }));
            $composite->push(new Sanger::Graphics::Glyph::Rect({
                'x'          => $start-1,
                'y'         => $sp + 2*$ih + $isp,
                'width'      => $end - $start + 1,
                'height'     => 0,
                "colour"     => 'black',
            }));
        }

        ## Lets see if we can Show navigation ?...
        if($navigation) {
            $composite->{'zmenu'} = $self->zmenu( $f ) if $self->can('zmenu');
            $composite->{'href'}  = $self->href(  $f ) if $self->can('href');
        }

        $self->push($composite);
    }

    ## horizontal grid
    my $grid = new Sanger::Graphics::Glyph::Composite();
    ## top spacer
    $grid->push(new Sanger::Graphics::Glyph::Rect({
        'x'         => 0,
        'y'         => 0,
        'width'     => $vc_length,
        'height'    => 0,
    }));
    ## lines
    foreach (($sp+$ih, $sp+$ih+$isp)) {
        $grid->push(new Sanger::Graphics::Glyph::Rect({
            'x'         => 0,
            'y'         => $_,
            'width'     => $vc_length,
            'height'    => 0,
            'colour'    => 'black',
        }));
    }
    ## bottom spacer
    $grid->push(new Sanger::Graphics::Glyph::Rect({
        'x'         => 0,
        'y'         => $h,
        'width'     => $vc_length,
        'height'    => 0,
    }));
    $self->push($grid);

    ## No features show "empty track line" if option set....  ##
    $self->errorTrack( "No ".$self->my_label." in this region" )
        if( $Config->get('_settings','opt_empty_tracks')==1 && $flag );
}

1;

