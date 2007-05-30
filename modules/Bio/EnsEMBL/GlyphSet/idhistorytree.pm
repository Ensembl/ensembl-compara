package Bio::EnsEMBL::GlyphSet::idhistorytree;

=head1 NAME

EnsEMBL::Web::GlyphSet::idhistorytree;

=head1 SYNOPSIS


=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Bethan Pritchard - bp1@sanger.ac.uk

=cut
use strict;
use vars qw(@ISA $SCORE_COLOURS);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Feature;
use EnsEMBL::Web::Component;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

my $k;
#warn ("A-0:".localtime());


sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);
  my $Config = $self->{'config'};   
  my $history_tree = $self->{'container'}; 
  my $a_id = $self->{'config'}->{_object}->stable_id;

  ## Define basic set up variables ##
  my $panel_width = $Config->image_width();
  my ($fontname, $fontsize) = $self->get_font_details('medium');
  my( $fontname_o, $fontsize_o ) = $self->get_font_details( 'label' );
  my @res_o = $self->get_text_width( 0, 'X', '', 'font'=>$fontname_o, 'ptsize' => $fontsize_o );
  my $th_o = $res_o[3];

  my $fontheight = 5;
  my $bg = $Config->get('_settings', 'bgcolor2');

  ## Variable declaration ##

  my $x = 140;
  my $y = 100;  
  my $working_length = $panel_width -160;
  my (%xc, %yc, @ns);

  ## Define Score colours ##
 
  my $cmap = $Config->colourmap();
  $SCORE_COLOURS  ={
	   0  => 'CCCCCC',
	  49  => 'FFF400',
	  50  => 'FFAA00',   
	  75  => 'FF5600',
	  90  => 'FF1900',  
	  97  => 'BB0000',
	  99  => '690000',
	  100 => '000000',
  };
  for my $k (keys %$SCORE_COLOURS) {
    $cmap->add_hex($SCORE_COLOURS->{$k});
  }
  my $branch_col;   
  ## Set X coordinates ##

  my @temp = @{$history_tree->get_release_display_names};
  my @releases = sort ({$a <=> $b} @temp);
  my $count = @releases;
  $count -=1;
  my $interval = $working_length / $count;
  my $temp_x = 140; 

  my @unique_ids =@{$history_tree->get_unique_stable_ids};
  my $species = $ENV{'ENSEMBL_SPECIES'};
   ## Set Y coordinates ##
  foreach my $id( @unique_ids){
	my $param2 =  $self->{'config'}->{_object}->type eq 'Translation' ? 'peptide' : lc($self->{'config'}->{_object}->type);
	my $id_l =  qq(/$species/idhistoryview?$param2=$id); 
    my $y_coord = $y;
    $yc{$id} = $y_coord;
    $y +=50; 
    # label unique stable IDs
    my $id_label = new Sanger::Graphics::Glyph::Text({
     'x'         => 5,
     'y'         => $y_coord,
      'width'    => 140,
     'height'    => $fontheight,
     'font'      => $fontname,
     'ptsize'    => $fontsize,
     'halign'    => 'left',
     'colour'    => 'blue',
     'text'      =>  $id,
     'href'     =>   $id_l
    });

   $self->push($id_label);
   ## Highlight the focus id ## 
   if ($id eq $a_id){
	   $self->unshift( new Sanger::Graphics::Glyph::Rect({
	        'x'         => -5,
	        'y'         => $y_coord - 15,
	        'width'     => $panel_width + 20,
	        'height'    => 30,
	        'colour'    => $bg,
	    }));
   }
  }

 foreach my $r (@releases){
     $xc{$r} = $temp_x;
     $temp_x += $interval;
 }

  my $last_rel = $releases[$count];

  my @events = @{ $history_tree->get_all_StableIdEvents };
  
   ## Draw Score boxes ##

   my $boxxcoord = $x -90;
  
   foreach my $sc (sort {$b<=>$a} keys %$SCORE_COLOURS){
	my $colour = $SCORE_COLOURS->{$sc}; 
	my $scorebox = new Sanger::Graphics::Glyph::Rect({
        'x'         => $boxxcoord,
        'y'         => 50,
        'width'     => 20,
        'height'    => 10,
        'colour'    => $colour,
    });
    $self->push($scorebox);
    my $sc_label;
    $sc = $sc/100; 
    $sc = sprintf("%.2f", $sc);
    if ($sc == 0){$sc_label = "Unknown"; }
    elsif ($sc <=0.49 ){$sc_label ="<=0.49" ;}
    elsif ($sc ==1){$sc_label = "=" .$sc;}
    else {$sc_label = ">=". $sc; }

    my $score_text = new Sanger::Graphics::Glyph::Text({
     'x'         => $boxxcoord + 25,
     'y'         => 55,
     'height'    => $fontheight,
     'font'      => $fontname,
     'ptsize'    => $fontsize,
     'halign'    => 'left',
     'colour'    => 'black',
     'text'      => $sc_label,
     });
    $self->push($score_text);

    my $score_label = new Sanger::Graphics::Glyph::Text({
     'x'         => 1,
     'y'         => 55,
     'height'    => $fontheight,
     'font'      => $fontname,
     'ptsize'    => $fontsize,
     'halign'    => 'left',
     'colour'    => 'black',
     'text'      => 'Score',
    });
    $self->push($score_label);
    $boxxcoord += 65;
   }

   ## Define nodes Nodes ##
    
   my @x_c = values (%xc);
   my @sortedx = sort ({$a <=> $b} @x_c);
   foreach my $a_id (@{ $history_tree->get_all_ArchiveStableIds }) {
    
    # only draw node if the version from the next release is different or if this version links to a different id      
    my $true = 0;
    my $final_rel = 0;
    my $first_rel =$last_rel;

    my ($x, $y) = @{ $history_tree->coords_by_ArchiveStableId($a_id) };
    my $id = $a_id->stable_id;
    my $version = $a_id->version;
    my $arelease = $a_id->release;

    foreach my $e (@events){
      my $old = $e->old_ArchiveStableId;
      my $new = $e->new_ArchiveStableId;
      next unless ($old && $new);
      if ($new->stable_id eq $id && $new->version == $version){
          my $new_rel = $new->release;
          if ($new_rel >= $final_rel){$final_rel = $new_rel;}            
          if ($new_rel <+ $first_rel){$first_rel = $new_rel;}
      }
      if ($old->stable_id eq $id && $old->version == $version){
          my $old_rel = $old->release;
          if ($old_rel >= $final_rel){$final_rel = $old_rel;}
          if ($old_rel <+ $first_rel){$first_rel = $old_rel;}
      }

      if ($id eq $new->stable_id && $version == $new->version){
         unless ($new->stable_id eq $old->stable_id) {$true =1;}
      }       
      if ($id eq $old->stable_id && $version == $old->version){
         unless ($old->stable_id eq $new->stable_id) {$true =1;}
      }
    }     
   
    my ($zmenu, $href ) = $self->zmenu_node($a_id);
    my $xcoord = $sortedx[$x];
    my $ycoord = $yc{$a_id->stable_id};
    my $node_col = $SCORE_COLOURS->{'100'};
    my $node = new Sanger::Graphics::Glyph::Rect({
        'x'         => $xcoord,
        'y'         => $ycoord -1.5,
        'width'     => 3,
        'height'    => 3,
        'colour'    => $node_col,
        'zmenu'     => $zmenu,
    });
    push (@ns, $node);

    my $nl = $a_id->version;
    my $node_label = new Sanger::Graphics::Glyph::Text({
      'x'         => $xcoord,
      'y'         => $ycoord +7,
      'height'    => $fontheight,
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'halign'    => 'left',
      'colour'    => 'black',
      'text'      => $nl,
      'absolutey' => 1,
    });
    $self->push($node_label);
   }



  ## Draw branches ##
  foreach my $event (@events) {
    my $old = $event->old_ArchiveStableId;
    my $new = $event->new_ArchiveStableId;

    next unless ($old && $new);

    my $old_id = $old->stable_id .".".$old->version;
    my $new_id = $new->stable_id."." .$new->version;
    my $escore = $event->score;
    $escore = $escore * 100;
    my $score_group; 
    if ($escore >=100 ){$score_group = '100' ;}
    elsif ($escore >=99 ){$score_group = '99' ;}
    elsif ($escore >=97 ){$score_group = '97' ;}
    elsif ($escore >=90 ){$score_group = '90' ;}
    elsif ($escore >=75 ){$score_group = '75' ;}
    elsif ($escore >=50 ){$score_group = '50' ;}
    elsif ($escore >=49 ){$score_group = '49' ;}
    elsif ($escore >=0 ){$score_group = '0' ;}
    $branch_col = $SCORE_COLOURS->{$score_group};

    my $zmenu_s = $self->zmenu_score($event);
    my ($oldx, $oldy) = @{$history_tree->coords_by_ArchiveStableId($old)};
    my ($newx, $newy) = @{$history_tree->coords_by_ArchiveStableId($new)};
    if ($oldy == $newy){
      my $y_coord = $yc{$old->stable_id};
      my $x_coord = $sortedx[$oldx];
      my $length = $sortedx[$newx] - $sortedx[$oldx];
      my $xend = $x_coord + $length;
      my $y_end = $y_coord +1;
      my $hbr = new Sanger::Graphics::Glyph::Poly({
         'x'         => $x_coord,
         'points'    => [$x_coord, $y_coord, $xend, $y_coord, $xend, $y_end, $x_coord,$y_end],
         'width'     => 0.25,
         'colour'    => $branch_col,
		 'absolutey' => 1,
		 'absolutewidth' => 1,
         'zmenu'     => $zmenu_s,
      });
      $self->push($hbr);   
    } elsif($oldx == $newx) {
      my $y_coord = $yc{$old->stable_id};
      my $x_coord = $sortedx[$oldx] ;
      my $height = $yc{$new->stable_id} - $yc{$old->stable_id};
      my $xend = $x_coord + $height;
      my $y_end = $y_coord +1;
      my $vbr = new Sanger::Graphics::Glyph::Poly({
         'x'         => $x_coord,
         'points'    => [$x_coord, $y_coord, $xend, $y_coord, $xend, $y_end, $x_coord,$y_end],
         'width'     => 0.25,
         'colour'    => $branch_col,
         'zmenu'    => $zmenu_s,
      });
      $self->push($vbr);
    } else {
      my $x_coord = $sortedx[$oldx];
      my $y_coord = $yc{$old->stable_id};
      my $x_end = $sortedx[$newx];
      my $y_end = $yc{$new->stable_id};
      my $dbr = new Sanger::Graphics::Glyph::Poly({
         'x'         => $x_coord,
         'points'    => [$x_coord, $y_coord, $x_end, $y_end, $x_end+1,$y_end+1, $x_coord+1, $y_coord+1 ],
         'width'     => 1,
         'colour'    => $branch_col,
		 'absolutey' => 1,
		 'absolutewidth' => 1,
         'zmenu'    => $zmenu_s,
      });
      $self->push($dbr);
    }
    
  }	   
  ## Draw the nodes ##
  foreach my $n (@ns){
	$self->push($n);
} 
  ## Draw scalebar ##
 
  my $mid_point = ($working_length /2 )+ 140;
  my $label = new Sanger::Graphics::Glyph::Text({
     'x'         => $mid_point,
     'y'         => $y + 40,
     'height'    => $fontheight,
     'font'      => $fontname,
     'ptsize'    => $fontsize,
     'halign'    => 'left',
     'colour'    => 'black',
     'text'      => 'Release',
     'absolutey' => 1,
  });

  $self->push($label); 

  my $bar = new Sanger::Graphics::Glyph::Line({
        'x'         => $x,
        'y'         => $y,
        'width'     => $working_length,
        'height'    => 0.25,
        'colour'    => 'black',
        'zindex' => 0,
  });
  $self->push($bar);  

  foreach my $r (@releases){
    my $x_coord = $xc{$r};
    my $ty = $y + 8;
    #if ($r == $last_rel){ $x_coord = $working_length - 0.25 + 60};    
     
    my $tick = new Sanger::Graphics::Glyph::Line({
        'x'         => $x_coord,
        'y'         => $y,
        'width'     => 0.25,
        'height'    => -4,
        'colour'    => 'black',
        'zindex' => 1,
    });
    $self->push($tick);
  
   my $rel_text = new Sanger::Graphics::Glyph::Text({
     'x'         => $x_coord -3,
     'y'         => $ty,
     'height'    => $fontheight,
     'font'      => $fontname,
     'ptsize'    => $fontsize,
     'halign'    => 'left',
     'colour'    => 'black',
     'text'      => $r,
     'absolutey' => 1,
   });
   $self->push($rel_text);  
      
  }
 #warn ("B-0:".localtime());      


 return 1;
}


sub zmenu_node {
  my( $self, $archive_id ) = @_;
  my $Config = $self->{'config'};
  my $param =  $archive_id->type eq 'Translation' ? 'peptide' : lc($archive_id->type);
  my $type = ucfirst $param; 
  my $id = $archive_id->stable_id .".". $archive_id->version;
  my $rel = $archive_id->release;
  my $assembly = $archive_id->assembly;  
  my $db = $archive_id->db_name;
  my $link = _archive_link($archive_id, $Config);

  my $zmenu = { 
		        caption         => $id,
                "10:$type: $link" =>'', 
                "20:Release: $rel" =>'',
                "30:Assembly: $assembly" =>'',
                "40:Database: $db" =>, 
	      };


  return ($zmenu, $link) ;
}

sub _archive_link {
  my ($object, $Config) = @_;
  my $release = $object->release;
  my $version = $object->version;
  my $type =  $object->type eq 'Translation' ? 'peptide' : lc($object->type);	
  my $name = $object->stable_id . "." . $object->version;
  my ($url, $id);
  my $site_type;
  if ($object->is_current) {
    $url = "http://www.ensembl.org/";
  }
  else {
    my %archive_sites;
    map { $archive_sites{ $_->{release_id} } = $_->{short_date} }@{ $Config->species_defs->RELEASE_INFO }; 
    if (exists $archive_sites{$release}){$url = "http://$archive_sites{$release}.archive.ensembl.org/"; }
    $url =~ s/ //;
    $site_type = "archived ";
  }
   $url .=  $ENV{'ENSEMBL_SPECIES'}."/";
   my $view = $type."view";
   if ($type eq 'peptide') {
     $view = 'protview';
   }
   elsif ($type eq 'transcript') {
    $view = 'transview';
   }
   
   $id = qq(<a href="$url$view?$type=$name">$name</a>);
  
  unless ($id =~/http/){ $id = qq($name);}
  return $id; 
}

sub zmenu_score {
  my( $self, $event) = @_;
  my $Config = $self->{'config'};
  my $old = $event->old_ArchiveStableId;
  my $old_id = $old->stable_id .".".$old->version;
  my $new = $event->new_ArchiveStableId;
  my $s = $event->score;
  my $new_id = $new->stable_id ."." .$new->version;
  my $old_link = _archive_link($old, $Config);
  my $new_link = _archive_link($new, $Config);
  my $oldRel = $old->release;
  my $oldAss = $old->assembly;
  my $oldDb = $old->db_name;
  my $newRel = $new->release;
  my $newAss = $new->assembly;
  my $newDb = $new->db_name;
  if ($s == 0){$s ="Unknown";}
  else {$s = sprintf("%.1f", $s);}  

   my $zmenu = {
                 caption  => 'Similarity Match',
                 "10:Old Gene: $old_link"        =>'',
                 "20: Old Gene Release: $oldRel" =>'',
                 "30: Old Gene Assembly: $oldAss" =>'',
                 "40: Old Gene Database: $oldDb"  =>'',
                 "50: New Gene: $new_link"        =>'',
                 "60: New Gene Release: $newRel"  =>'',
                 "70: New Gene Assembly: $newAss" =>'',
                 "80: New Gene Database: $newDb"  =>'',
                 "90:Score: $s" => '', 
               };
  return $zmenu;
}

1;
