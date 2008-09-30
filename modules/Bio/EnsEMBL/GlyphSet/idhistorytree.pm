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
use vars qw(@ISA $SCORE_COLOURS $COLOURS);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Feature;
use EnsEMBL::Web::Component;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

my $k;
#warn ("A-0:".localtime());
my %asmbl;

sub render_normal { 
  my ($self) = @_;
  return unless ($self->strand() == 1);
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
  my $bg = $Config->get_parameter('bgcolour2') || 'background2';
   

  ## Variable declaration ##

  my $x = 140;
  my $y = 100;  
  my $working_length = $panel_width -160;
  my (%xc, %yc, @ns);

  ## Define Score colours ##
 
  my $cmap = $Config->colourmap();
  $SCORE_COLOURS  ={qw(
      0  CCCCCC
     49  FFF400
     50  FFAA00   
     75  FF5600
     90  FF1900  
     97  BB0000
     99  690000
    100  000000
  )};
  for my $k (keys %$SCORE_COLOURS) {
    $cmap->add_hex($SCORE_COLOURS->{$k});
  }
  my $branch_col;   
  ## Set X coordinates ##

  my @releases = sort {$a <=> $b} @{$history_tree->get_release_display_names};
#warn "Releases... @releases";
  my $count = scalar(@releases);
     $count --;
  my $interval = $working_length / $count;
  my $temp_x = 140; 

  my @unique_ids = @{ $history_tree->get_unique_stable_ids };
  my $species = $ENV{'ENSEMBL_SPECIES'};
  
   ## Set Y coordinates ##
  foreach my $id (@unique_ids) {
    my $param2 = $self->{'config'}->{_object}->type eq 'Translation' ? 'peptide' : lc($self->{'config'}->{_object}->type);
    my $id_l = qq(/$species/idhistoryview?$param2=$id); 
    my $y_coord = $y;
    $yc{$id} = $y_coord;
    $y +=50;
    
    # label unique stable IDs
    $self->push( $self->Text({
      'x'         => 5,
      'y'         => $y_coord,
      'width'     => 140,
      'height'    => $fontheight,
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'halign'    => 'left',
      'colour'    => 'blue',
      'text'      =>  $id,
      #'href'     =>   $id_l
    }));

    if ($id eq $a_id) { ## Highlight the focus id ##
      $self->unshift( $self->Rect({
        'x'         => -5,
        'y'         => $y_coord - 15,
        'width'     => $panel_width + 20,
        'height'    => 30,
        'colour'    => $bg,
      }));
    }
  }

  foreach my $r (@releases) {
     $xc{$r} = $temp_x;
     $temp_x += $interval;
  }

  my $last_rel = $releases[$count];

  my @events = @{ $history_tree->get_all_StableIdEvents };
  
  ## Draw Score boxes ##
  my $boxxcoord = $x -90;
  
  foreach my $sc (sort { $b<=>$a } keys %$SCORE_COLOURS) {
    my $colour = $SCORE_COLOURS->{$sc};  
    my $scorebox = $self->Rect({
      'x'         => $boxxcoord,
      'y'         => 50,
      'width'     => 20,
      'height'    => 10,
      'colour'    => $colour,
    });
    $self->push($scorebox);

    $sc = sprintf("%.2f", $sc/100);
    my $sc_label  = $sc == 0    ? "Unknown" 
                  : $sc <  0.5  ? "<0.50"
		  : $sc == 1    ? $sc
		  :               ">=".$sc
		  ;

    $self->push( $self->Text({
      'x'         => $boxxcoord + 25,
      'y'         => 55,
      'height'    => $fontheight,
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'halign'    => 'left',
      'colour'    => 'black',
      'text'      => $sc_label,
    }));

    $self->push( $self->Text({
      'x'         => 1,
      'y'         => 55,
      'height'    => $fontheight,
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'halign'    => 'left',
      'colour'    => 'black',
      'text'      => 'Score',
    }));
    $boxxcoord += 65;
  }

  ## Define nodes Nodes ##
  my @x_c = values (%xc);
  my @sortedx = sort ({$a <=> $b} @x_c);
  foreach my $a_id (@{ $history_tree->get_all_ArchiveStableIds }) {

    # only draw node if the version from the next release is different or if
    # this version links to a different id      
    my $true = 0;
    my $final_rel = 0;
    my $first_rel =$last_rel;

    my ($x, $y) = @{ $history_tree->coords_by_ArchiveStableId($a_id) };
    my $id = $a_id->stable_id;
    my $version = $a_id->version;
    my $arelease = $a_id->release;
#warn ">>>> $id($version/$arelease) $x <<>> $y <<<";
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
    my $node = $self->Rect({
        'x'         => $xcoord,
        'y'         => $ycoord - 1.5,
        'width'     => 3,
        'height'    => 3,
        'colour'    => $node_col,
        'href'     =>  $self->_url($zmenu),
        });
    push (@ns, $node);

    my $nl = $a_id->version;
    my $node_label = $self->Text({
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
    if ($escore >= 100) {$score_group = '100' ;}
    elsif ($escore >= 99) {$score_group = '99' ;}
    elsif ($escore >= 97) {$score_group = '97' ;}
    elsif ($escore >= 90) {$score_group = '90' ;}
    elsif ($escore >= 75) {$score_group = '75' ;}
    elsif ($escore >= 50) {$score_group = '50' ;}
    elsif ($escore < 50 and $escore > 0) {$score_group = '49' ;}
    elsif ($escore >=0) {$score_group = '0' ;}
    $branch_col = $SCORE_COLOURS->{$score_group};

    my $zmenu_s = $self->zmenu_score($event);
    my ($oldx, $oldy) = @{$history_tree->coords_by_ArchiveStableId($old)};
    my ($newx, $newy) = @{$history_tree->coords_by_ArchiveStableId($new)};
    
    if ($oldy == $newy) {
    
      my $y_coord = $yc{$old->stable_id};
      my $x_coord = $sortedx[$oldx];
      my $length = $sortedx[$newx] - $sortedx[$oldx];
      my $xend = $x_coord + $length;
      my $y_end = $y_coord +1;
      my $hbr = $self->Line({
         'x'         => $x_coord,
         'y'         => $y_coord,
         'height'    => 0,
         'width'     => $length,
         'colour'    => $branch_col,
         'absolutey' => 1,
           'absolutewidth' => 1,
         'clickwidth' => 2,
         'href'     => $self->_url($zmenu_s),
      });
      $self->push($hbr);   
    
    } elsif ($oldx == $newx) {
    
      my $y_coord = $yc{$old->stable_id};
      my $x_coord = $sortedx[$oldx] ;
      my $height = $yc{$new->stable_id} - $yc{$old->stable_id};
      my $xend = $x_coord + $height;
      my $y_end = $y_coord +1;
      my $vbr = $self->Line({
         'x'         => $x_coord,
         'y'         => $y_coord,
         'height'    => $height,
         'width'     => 0,
         'width'     => 0.25,
         'colour'    => $branch_col,
         'clickwidth' => 2,
         'zmenu'    => $zmenu_s,
      });
      $self->push($vbr);
      
    } else {
    
      my $x_coord = $sortedx[$oldx];
      my $y_coord = $yc{$old->stable_id};
      my $x_end = $sortedx[$newx];
      my $y_end = $yc{$new->stable_id};
      my $dbr = $self->Line({
         'x'         => $x_coord,
         'y'         => $y_coord,
         'height'    => $y_end - $y_coord,
         'width'     => $x_end - $x_coord,
         'colour'    => $branch_col,
          'absolutey' => 1,
          'absolutewidth' => 1,
         'clickwidth' => 2,
         'zmenu'    => $zmenu_s,
      });
      $self->push($dbr);
      
    }

  }       
  
  ## Draw the nodes ##
  foreach my $n (@ns){
    $self->push($n);
  } 

  ## Add assembly information ##

  my $asmbl_label = $self->Text({
        'x'         => 5,
       'y'         => $y,
       'height'    => $fontheight,
       'font'      => $fontname,
       'ptsize'    => $fontsize,
       'halign'    => 'left',
       'colour'    => 'black',
       'text'      => "Assembly",
       'absolutey' => 1,
 });

  $self->push($asmbl_label);

  my %archive_info = %{$Config->species_defs->get_config($species, 'ASSEMBLIES')}; 

  my @a_colours = ('contigblue1', 'contigblue2');
  my $i =0;
  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};
  my $strand = ">";

  foreach my $r (@releases){
    my $tempr = $r; 
    if ($tempr =~/\./){ $tempr=~s/\.\d*//; }
    my $current_r = $archive_info{$tempr}; 
    push @{$asmbl{$current_r}} , $r;
  }
  my %asmbl_seen;

  foreach my $key ( @releases){    
   my $tempr = $key; 
   if ($tempr =~/\./){ $tempr=~s/\.\d*//; }
    my $a = $archive_info{$tempr};
    if (exists $asmbl_seen{$a}){
      next;
    }
    else {
      $asmbl_seen{$a} = $key;    
      my $r = $asmbl{$a};    
      my @sorted = sort @{$r};
      my $size = @sorted;
      my $start = ($xc{$sorted[0]}) + 2;
      my $offset = $interval / 2;
      $start -= $offset;
      my $end = $start + ($interval * $size);
      $end -= 4;
      if ($sorted[0] == $releases[0]){ $start = ($xc{$sorted[0]}) -10; }
      if ($sorted[-1] == $releases[-1]) {$end = $xc{$sorted[-1]} +10; }
      my $length = $end - $start;
      my $colour = $a_colours[$i];     

      my $asmblbox = $self->Rect({
       'x'         => $start,
       'y'         => $y -3,
       'width'     => $length,
       'height'    => 15,
       'colour'    => $colour,
       'title'       => $a,
      });
      $self->push($asmblbox);
  
      my @res = $self->get_text_width(
       ($end-$start)*$pix_per_bp,
       $strand > 0 ? "$a " : " $a",
       $strand > 0 ? '1' : '0',
       'font'=>$fontname, 'ptsize' => $fontsize
      );

     if( $res[0] ) {
       my $tglyph = $self->Text({
        'x'          => $start +5,
        'height'     => $res[3],
        'width'      => $res[2]/$pix_per_bp,
        'textwidth'  => $res[2],
        'y'          => $y -3,
        'font'       => $fontname,
        'ptsize'     => $fontsize,
        'colour'     => 'white',
        'text'       => $a,
        'absolutey'  => 1,
       });
      $self->push($tglyph);
     }
     if ($i == 1){$i = 0;} 
     else {$i = 1;}
    }
  }
 
 ## Draw scalebar ##
  $y +=30;
  my $mid_point = ($working_length /2 )+ 140;
  my $label = $self->Text({
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

  my $bar = $self->Line({
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
   # if ($r == $last_rel){ $x_coord = $working_length - 0.25 + 60};    

    my $tick = $self->Line({
        'x'         => $x_coord,
        'y'         => $y,
        'width'     => 0.25,
        'height'    => -4,
        'colour'    => 'black',
        'zindex' => 1,
    });
    $self->push($tick);

    my $rel_text = $self->Text({
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
    'caption'        =>  $id,
    '90:'.$type      =>  $link, 
    '80:Release'     =>  $rel,
    '70:Assembly'    =>  $assembly,
    '60:Database'    =>  $db, 
  };

  return ($zmenu, $link) ;
}


sub _archive_link {
  my ($object, $Config) = @_;

  my $release = $object->release;
  my $version = $object->version;
  my $type =  $object->type eq 'Translation' ? 'peptide' : lc($object->type);    
  my $name = $object->stable_id . "." . $object->version;

  # no archive for old release, return un-linked display_label
  return $name if ($release < $Config->species_defs->EARLIEST_ARCHIVE);
  
  my $url;

  if ($object->is_current) {
    $url = "/";
  } else {

    
    #my %archive_sites = map { $_->{release_id} => $_->{short_date} }
    my %archive_sites = %{ $Config->species_defs->ENSEMBL_ARCHIVES }; 
    if ($archive_sites{$release}){
     $url = "http://$archive_sites{$release}.archive.ensembl.org/";
     $url =~ s/ //;
    } else { return $name;}
    
  }

  $url .=  $ENV{'ENSEMBL_SPECIES'};

  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }

   
  my $html = qq(<a href="$url/$view?$type=$name">$name</a>);
  if ($release >= 51 ){
    my $p;
    if ($type eq 'gene') {
      $type = 'Gene';
      $p = 'g';
    } else {
      $type = 'Transcript';
      $p = 't';
    }  
    $html = qq(<a href="$url/$type/Summary?$p=$name">$name</a>);
  } 

  return $html;
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
  my $oldType = $old->type;
  my $newRel = $new->release;
  my $newAss = $new->assembly;
  my $newDb = $new->db_name;
  my $newType = $new->type;
  if ($s == 0){$s ="Unknown";}
  else {$s = sprintf("%.2f", $s);}  

  my $zmenu = {
    caption             => 'Similarity Match',
    "100:Old $oldType:" => $old_link,
    "90:Old Release:"   =>  $oldRel,
    "80:Old Assembly:"  =>  $oldAss,
    "70:Old Database:"  =>  $oldDb,
    "60:New $newType:"  =>  $new_link,
    "50:New Release:"   =>  $newRel,
    "40:New Assembly:"  =>  $newAss,
    "30:New Database:"  =>  $newDb,
    "20:Score:"         =>  $s, 
  };
  return $zmenu;
}

1;
