package Bio::EnsEMBL::GlyphSet::Pprot_snp;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Bump;
use EnsEMBL::Web::GeneTrans::support;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
        'text'      => 'SNPs',
        'font'      => 'Small',
        'absolutey' => 1,
		
    });
    $self->label($label);
}

sub bump{
	my ($config ,$container, $glyph) = @_;
	if ($config->get('Pprot_snp', 'dep') > 0){ # we bump
            my $pix_per_bp    = $config->transform->{'scalex'};
			my $bump_start = int($glyph->x() * $pix_per_bp);
			my $bitmap_length = int($container->length() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
	    
            my $bump_end = $bump_start + int($glyph->width()*$pix_per_bp);
            if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
            my $row = & Sanger::Graphics::Bump::bump_row(
				      $bump_start,
				      $bump_end,
				      $bitmap_length,
				      );
            $glyph->y($glyph->y() + (1.5 * $row * 10));
        }
}


sub _init {
    my ($self) = @_;
    my $protein    = $self->{'container'};
    my $Config     = $self->{'config'};
	my $snps		= $protein->{'bg2_snps'};  
    my $x		   = 0;
	my $y          = 0;
    my $h          = 6;
	my $w      	   = 5;
    my $key        = "Prot SNP";    
	my $last_indel;
	
    if ($snps) {	
	foreach my $int (@$snps) {
	  $x++;
	  my $id     = $int->{'type'}; 
	  	  
	  if ($int->{'type'} eq 'insert' && ($last_indel ne $int->{'indel'})){
	  my $triangle = new Sanger::Graphics::Glyph::Poly({
                    'points'    => [ $x+2, $h+5,
                                     $x, $h,
                                     $x-2, $h+5  ],
                    'colour'    => $Config->get('Pprot_snp', $int->{'bg'}),
                    'absolutey' => 1,
					'absolutewidth' => 1,
					'zmenu' => {
						'caption' => "Insert Information",
						"00:Insert: ". $int->{'allele'} => "",
						"01:Start: $x" => "",
						'02:End: '.($x + 1)  => "",
						'03:Length: '. length($int->{'allele'}) => "", },
                });
		bump($Config, $protein, $triangle);
	   $self->push($triangle) if(defined $triangle);	   
	  }
	  
	  elsif ($int->{'type'} eq 'delete' && ($last_indel ne $int->{'indel'})){
	  my $triangle = new Sanger::Graphics::Glyph::Poly({
                    'points'    => [ $x+2, $h-5,
                                     $x, $h,
                                     $x-2, $h-5  ],
                    'colour'    => $Config->get('Pprot_snp', $int->{'bg'}),
                    'absolutey' => 1,
					'absolutewidth' => 1,
					'zmenu' => {
						'caption' => "Deletion Information",
						"00:Deletion: ". $int->{'allele'} => "",
						"01:Start: $x" => "",
						'02:End: '. ($x + length($int->{'allele'})) => "",
						'03:Length: '. length($int->{'allele'})  => "", },
                });
	  bump($Config, $protein, $triangle);	  
	  $self->push($triangle) if(defined $triangle);	  
	  }
	  
	  elsif ($int->{'type'} eq 'snp' || $int->{'type'} eq 'syn'){  
	    my $type = $int->{'type'} eq 'snp' ? 'Non-synonymous' : 'Synonymous' ;
		my $snp  = '';
		if ($int->{'type'} eq 'snp'){
			$snp = "Alternative Residues: ". $int->{'pep_snp'}  ;
		}else{
			$snp = "Alternative Codon: ";
			for my $letter ( 0..2 ){
				$snp .= $int->{'ambigcode'}[$letter]  ? '('.$int->{'ambigcode'}[$letter].')' : $int->{'nt'}[$letter];   
			}
		}
		my $rect = new Sanger::Graphics::Glyph::Rect({
		'x'        => $x,
		'width'    => $w,
		'height'   => $h,
		'colour'   => $Config->get('Pprot_snp', $int->{'bg'}),
		'absolutey' => 1,
		'absolutewidth' => 1,
		'zmenu' => {
			'caption' => "SNP Information",
			"00:SNP Type: $type"   => "",
			"01:Residue: $x" => "",
			"03:$snp" => "", },
	
	    });
		bump($Config, $protein, $rect);				
	    $self->push($rect) if(defined $rect);
	}else{
		next;
	}
		$last_indel =  $int->{'indel'};
	}
	
    }
   
}
1;




















