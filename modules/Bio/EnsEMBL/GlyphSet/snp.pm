package Bio::EnsEMBL::GlyphSet::snp;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'SNP',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);

    my $VirtualContig = $self->{'container'};
    my $Config        = $self->{'config'};
    my $y             = 0;
    my $h             = 8;
    my $highlights    = $self->highlights();
    my $cmap          = new ColourMap;
    my $snp_col       = $Config->get('snp','col');
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $bitmap_length = $VirtualContig->length();
    my $type          = $Config->get('gene','src');
	print STDERR "snp.pm: ".$self->glob_bp()." *\n";
    my @xf            = $VirtualContig->get_all_ExternalFeatures( $self->glob_bp() );
    my @snp;

    ## need to sort external features into SNPs or traces and treat them differently
    foreach my $f (@xf){
		if ($f->isa("Bio::EnsEMBL::ExternalData::Variation")) {
	    	# A SNP
	    	push(@snp, $f);
		}
    }

    my $rect;
    my $colour;
    foreach my $s (@snp) {
	my $x = $s->start();
	my $id = $s->id();
	#print STDERR "SNP start: ", $x, " ID:", $s->id(),  "\n";
	my $snpglyph = new Bio::EnsEMBL::Glyph::Rect({
	    'x'      => $x,
	    'y'      => 0,
	    'width'  => 2,
	    'height' => $h,
	    'colour' => $snp_col,
	    'absolutey'  => 1,
            'zmenu'     => { 
		'caption' => "SNP: $id",
		'SNP properties' => "/perl/snpview?snp=$id",
		'dbSNP data' => "http://www.ncbi.nlm.nih.gov/SNP/snp_ref.cgi?type=rs&rs=$id",
	    },
	});
	
	foreach ($s->each_DBLink()){
	    next if ($_->database() =~ /JCM/);
	    my $db  = $_->database() . " data";
	    my $pid = $_->primary_id();
	    
	    if ($db =~ /TSC/){
		$snpglyph->{'zmenu'}->{$db} = "http://snp.cshl.org/db/snp/snp?name=" . $pid;
	    } elsif ($db =~ /CGAP/){
		$snpglyph->{'zmenu'}->{$db} = "http://lpgws.nci.nih.gov:82/perl/gettrace.pl?type=7&trace=" . $pid;			
	    } elsif ($db =~ /HGBASE/){
		$snpglyph->{'zmenu'}->{$db} = "http://www.ebi.ac.uk/cgi-bin/mutations/hgbasefetch?" . $pid;			
	    }
	}	
	
	$self->push($snpglyph);
    }
}

1;
