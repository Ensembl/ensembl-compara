package Bio::EnsEMBL::GlyphSet::das;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Composite;
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use ExtURL;
use SiteDefs;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => $self->{'extras'}->{'caption'},
	'font'      => 'Small',
	'absolutey' => 1
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    my $Config         	= $self->{'config'};
    my $das_name        = $self->das_name();
	my $strand          = $Config->get($das_name, 'str');
# If strand is 'r' or 'f' then we display everything on one strand (either
# at the top or at the bottom!

    return if( $strand eq 'r' && $self->strand() != -1 || $strand eq 'f' && $self->strand() != 1 );
	
    my $tstrand = $self->strand;
    my $cmap            = $Config->colourmap();
    my $feature_colour 	= $Config->get($das_name, 'col') || $Config->colourmap()->id_by_name('contigblue1');
	my $dep             = $Config->get($das_name, 'dep');
	my $group           = $Config->get($das_name, 'group');
    my $vc 		        = $self->{'container'};
    my $border          = $Config->colourmap()->id_by_name('black');
    my $red             = $Config->colourmap()->id_by_name('red');
    my ($w,$h)          = $Config->texthelper()->real_px2bp('Tiny');
    my $length          = $vc->length() +1;
    my @bitmap         	= undef;
    my $pix_per_bp  	= $Config->transform->{'scalex'};
    my $bitmap_length 	= int($length * $pix_per_bp);

    $w *= $length/($length-1);
    
    my @features;
    eval{
        @features = $vc->get_all_DASFeatures();
    };
    if($@) {
        print STDERR "----------\n",$@,"---------\n";
        return;
    }
    my $link_text = $self->{'extras'}->{'linktext'} || 'Additional info';
	my $ext_url;
	if( $self->{'extras'}->{'linkURL'} ) {
		if($self->{'extras'}->{'name'} =~ /^extdas_/) {
			$ext_url = ExtURL->new(
				$self->{'extras'}->{'linkURL'} => $self->{'extras'}->{'linkURL'}
			);
		} else {
			$ext_url = ExtURL->new();		
		}
	}
	
    my $text = '';
    my $empty_flag =1;

    my $STRAND = $self->strand();
    if($group==1) {
	    my %grouped;
	    foreach my $f(@features){
		    next unless ( $f->das_dsn() eq $self->{'extras'}->{'dsn'} );
            if($f->das_type_id() eq '__ERROR__') {
                $self->errorTrack(
					'Error retrieving '.$self->{'extras'}->{'caption'}.' features ('.$f->id.')'
				);
		    	return;
            }
            next if ($f->das_type_id() =~ /contig/i);       # raw_contigs
            next if ($f->das_type_id() =~ /component/i);       # clones
            next if ($f->das_type_id() =~ /karyotype/i);    # karyotype 
    		next if $strand eq 'b' &&
                ( $f->strand() !=1 && $STRAND==1 || $f->strand() ==1 && $STRAND==-1);
    	    my $fid = $f->das_id;
		    next unless $fid;
		    $fid = "G:".$f->das_group_id if $f->das_group_id;
		    $grouped{$fid} = [] unless(exists $grouped{$fid});
	   	    push @{$grouped{$fid}}, $f;
            $empty_flag =0; # We have a feature (its on one of the strands!)
	    }

        if($empty_flag) {
			$self->errorTrack(
				'No '.$self->{'extras'}->{'caption'}.
				' features in this region'
			);
		    return;
        }	
		foreach my $value (values %grouped) {
			my $f = $value->[0];
		## Display if not stranded OR
			my @features = sort { $a->das_start <=> $b->das_start } @$value;
			my $start = $features[0]->das_start;
			my $end = $features[-1]->das_end;
        ### A general list of features we don't want to draw via DAS ###
       
			my $id      	= $f->das_id();
			my $display_id  = "ID: " .  $f->das_id();
		#print STDERR "Drawing feature: ",$f->das_id(),' - ',$f->das_start(), " - ",
		#      $f->das_end(), " - ", $feature_colour,"\n";
        ### if there is an error in the retrieval of the DAS source then
        ### a feature with ->id "__ERROR__" is added to the feature list
        ### this forces an error text to be displayed below [ error message is in ->das_id() ]
        	$empty_flag = 0;

			my $zmenu = {
            	'caption'         => $self->{'extras'}->{'label'},
                "DAS source info" => $self->{'extras'}->{'url'},
        	};
			$zmenu->{"TYPE: ". $f->das_type_id()      } = ''
				if $f->das_type_id() && uc($f->das_type_id())!='NULL';
			$zmenu->{"METHOD: ". $f->das_method_id()  } = ''
				if $f->das_method_id() && uc($f->das_method_id())!='NULL';
			$zmenu->{"CATEGORY: ". $f->das_type_category() } => ''
				if $f->das_type_category() && uc($f->das_type_category())!='NULL';
        
   		# JS5: If we have an ID then we can add this to the Zmenu and
		#      also see if we can make a link to any additional information
		#      about the source.
			my $href=undef;
			if($id && $id ne 'null') {
				if($self->{'extras'}->{'linkURL'}){
					$zmenu->{$link_text} = $href = $ext_url->get_url( $self->{'extras'}->{'linkURL'}, $id );
				}
	    		$zmenu->{$display_id} = '';
			#print STDERR "DAS SNP ID: $id\n";
			}
			my $Composite = new Bio::EnsEMBL::Glyph::Composite({
				'y'            => 0,
				'x'            => $start,
				'absolutey'    => 1,
            	'zmenu'     => $zmenu,
			});
			$Composite->{'href'} = $href if $href;
			$Composite->bordercolour($feature_colour);
			foreach(@features) {
				$end = $_->das_end if $end <= $_->das_end;
				my $glyph = new Bio::EnsEMBL::Glyph::Rect({
    	        	'x'      	=> $_->das_start(),
	    			'y'      	=> 0,
	    			'width'  	=> $_->das_end()-$_->das_start(),
		    		'height' 	=> 8,
		    		'colour' 	=> $feature_colour,
	    			'absolutey' => 1,
            		'zmenu'     => $zmenu
				});
				$Composite->push($glyph);
			}
		
	    	if ($dep > 0) { # we bump
            	my $bump_start = int($Composite->x() * $pix_per_bp);
            	$bump_start = 0 if ($bump_start < 0);

            	my $bump_end = $bump_start + int($Composite->width()*$pix_per_bp);
            	$bump_end = $bitmap_length if $bump_end > $bitmap_length;
            	my $row = &Bump::bump_row(
				    $bump_start,
					$bump_end,
					$bitmap_length,
					\@bitmap
            	);
    			next if ($row > $dep);
            	$Composite->y($Composite->y() - $tstrand * 1.4 * $row * $h);
	    	}
	    	$self->push($Composite);     
    	}
  	} else {
		foreach my $f(@features){
## Display if not stranded OR
#            print STDERR "got feature:", $f->das_dsn(), "-", $self->{'extras'}->{'dsn'},"\n";
    		next unless ( $f->das_dsn() eq $self->{'extras'}->{'dsn'} );
#            print STDERR "passed DSN test\n";
        	if($f->das_type_id() eq '__ERROR__') {
				$self->errorTrack(
					'Error retrieving '.$self->{'extras'}->{'caption'}.
					' features ('.$f->id.')'
				);
		    	return;
        	}
	        next if ($f->das_type_id() =~ /contig/i);       # raw_contigs
            next if ($f->das_type_id() =~ /component/i);       # clones
    	    next if ($f->das_type_id() =~ /karyotype/i);    # karyotype bands
#            print STDERR "passed type test\n";
	        $empty_flag =0; # We have a feature (its on one of the strands!)
    		next if $strand eq 'b' &&
                ( $f->strand() !=1 && $STRAND==1 || $f->strand() ==1 && $STRAND==-1);
                
#            print STDERR "passed strand test\n";
        
        	### A general list of features we don't want to draw via DAS ###
       
		   	my $id = $f->das_id();
			my $display_id      = "ID: $id";
        
 
		#print STDERR "Drawing feature: ",$f->das_id(),' - ',$f->das_start(), " - ", $f->das_end(), " - ", $feature_colour,"\n";
        ### if there is an error in the retrieval of the DAS source then
        ### a feature with ->id "__ERROR__" is added to the feature list
        ### this forces an error text to be displayed below [ error message is in ->das_id() ]
        	$empty_flag = 0;

			my $zmenu = {
                	'caption'                       => $self->{'extras'}->{'label'},
                	"DAS source info"               => $self->{'extras'}->{'url'},
    	    };
			$zmenu->{"TYPE: ". $f->das_type_id()      } = ''
				if $f->das_type_id() && uc($f->das_type_id())!='NULL';
			$zmenu->{"METHOD: ". $f->das_method_id()  } = ''
				if $f->das_method_id() && uc($f->das_method_id())!='NULL';
			$zmenu->{"CATEGORY: ". $f->das_type_category() } => ''
				if $f->das_type_category() && uc($f->das_type_category())!='NULL';
        
   		# JS5: If we have an ID then we can add this to the Zmenu and
		#      also see if we can make a link to any additional information
		#      about the source.
			my $href=undef;
			if($id && $id ne 'null') {
				if($self->{'extras'}->{'linkURL'}){
					$zmenu->{$link_text} = $href = $ext_url->get_url( $self->{'extras'}->{'linkURL'}, $id );
				}
	    		$zmenu->{$display_id} = '';
			#print STDERR "DAS SNP ID: $id\n";
			}
			my $Composite = new Bio::EnsEMBL::Glyph::Composite({
				'y'            => 0,
				'x'            => $f->das_start(),
				'absolutey'    => 1,
            	'zmenu'     => $zmenu,
			});
			$Composite->{'href'} = $href if $href;
		
			my $glyph = new Bio::EnsEMBL::Glyph::Rect({
    	        'x'      	=> $f->das_start(),
		    	'y'      	=> 0,
	    		'width'  	=> $f->das_end()-$f->das_start(),
		    	'height' 	=> 8,
	    		'colour' 	=> $feature_colour,
		    	'absolutey' => 1,
    	        'zmenu'     => $zmenu
			});
			$Composite->push($glyph);
        #$glyph->bordercolour($border);
		    if ($dep > 0) { # we bump
        	    my $bump_start = int($Composite->x() * $pix_per_bp);
            	$bump_start = 0 if ($bump_start < 0);

	            my $bump_end = $bump_start + int($Composite->width()*$pix_per_bp);
    	        $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
        	    my $row = &Bump::bump_row(
				    $bump_start,
					$bump_end,
					$bitmap_length,
					\@bitmap
	            );
    			next if ($row > $dep);
        	    $Composite->y($Composite->y() - $tstrand * 1.4 * $row * $h);
		    }
		    $self->push($Composite);     
	    }
    
		$self->errorTrack(
			'No '.$self->{'extras'}->{'caption'}.
			' features in this region'
		) if $empty_flag;
    }   
}

sub das_name {
    my ($self) = @_;
    return $self->{'extras'}->{'name'};
}

1;
