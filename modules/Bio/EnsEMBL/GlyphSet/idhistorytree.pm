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
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Feature;
use EnsEMBL::Web::Component;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

#sub fixed { return 1;}
my $k;
#warn ("A-0:".localtime());


sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);
  my $Config = $self->{'config'};   
  my $history_tree = $self->{'container'}; 
 

  ## Define basic set up variables ##
  my $panel_width = $Config->image_width();
  my ($fontname, $fontsize) = $self->get_font_details('medium');
  my $fontheight = 5;
  
  ## Variable declaration ##

  my $x = 140;
  my $y = 70;  
  my $working_length = $panel_width -160;
  my (%xc, %yc);    
  ## Set X coordinates ##

  my @temp = @{$history_tree->get_release_display_names};
  my @releases = sort ({$a <=> $b} @temp);
  my $count = @releases;
  $count -=1;
  my $interval = $working_length / $count;
  my $temp_x = 140; 

  my @unique_ids =@{$history_tree->get_unique_stable_ids};
  
  ## Set Y coordinates ##
  foreach my $id( @unique_ids){
    my $y_coord = $y;
    $yc{$id} = $y_coord;
    $y +=50; 
    # label unique stable IDs
    my $id_label = new Sanger::Graphics::Glyph::Text({
     'x'         => 5,
     'y'         => $y_coord,
     'height'    => $fontheight,
     'font'      => $fontname,
     'ptsize'    => $fontsize,
     'halign'    => 'left',
     'colour'    => 'black',
     'text'      => $id,
     'absolutey' => 1,
    });

   $self->push($id_label);
  }

 foreach my $r (@releases){
     $xc{$r} = $temp_x;
     $temp_x += $interval;
    }

  my $last_rel = $releases[$count];

  my @events = @{ $history_tree->get_all_StableIdEvents };
  

   ## Draw Nodes ##
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
   
    if ($arelease eq $final_rel || $arelease eq $first_rel){$true =1;}  
 #   next unless ($true==1);
    $true = 0;
    my ($zmenu, $href ) = $self->zmenu_node($a_id);
    my $xcoord = $sortedx[$x];
    my $ycoord = $yc{$a_id->stable_id};

    

    my $node = new Sanger::Graphics::Glyph::Rect({
        'x'         => $xcoord,
        'y'         => $ycoord -1.5,
        'width'     => 3,
        'height'    => 3,
        'colour'    => 'navyblue',
        'zmenu'     => $zmenu,
    });
    $self->push($node);
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
    
    my $zmenu_s = $self->zmenu_score($event);
    my ($oldx, $oldy) = @{$history_tree->coords_by_ArchiveStableId($old)};
    my ($newx, $newy) = @{$history_tree->coords_by_ArchiveStableId($new)};
    if ($oldy == $newy){
      my $y_coord = $yc{$old->stable_id};
      my $x_coord = $sortedx[$oldx];
      my $length = $sortedx[$newx] - $sortedx[$oldx];

      my $hbr = new Sanger::Graphics::Glyph::Line({
         'x'         => $x_coord,
         'y'         => $y_coord,
         'width'     => $length,
         'height'    => 0.25,
         'colour'    => 'navyblue',
         'zindex' => 0,
      });
      $self->push($hbr);   
      unless ($old_id eq $new_id){ 
       my $score = new Sanger::Graphics::Glyph::Circle({
           'x'        => $x_coord + ($length*0.55),
           'y'        => $y_coord,
           'diameter' => 5,
           'colour'   => 'red',
           'filled'   => 1,
           'zmenu'    => $zmenu_s,
       });
       $self->push($score);  
      }
    } elsif($oldx == $newx) {
      my $y_coord = $yc{$old->stable_id};
      my $x_coord = $sortedx[$oldx] ;
      my $height = $yc{$new->stable_id} - $yc{$old->stable_id};
      warn "old = $yc{$old->stable_id} new = $yc{$new->stable_id}";
      my $vbr = new Sanger::Graphics::Glyph::Line({
         'x'         => $x_coord,
         'y'         => $y_coord,
         'width'     => 0.25,
         'height'    => $height,
         'colour'    => 'navyblue',
         'zindex'    => 0,
      });
      $self->push($vbr);
    } else {
      my $x_coord = $sortedx[$oldx];
      my $y_coord = $yc{$old->stable_id};
      my $height = $yc{$new->stable_id} - $yc{$old->stable_id};
      my $length = $sortedx[$newx] - $sortedx[$oldx];
      my $dbr = new Sanger::Graphics::Glyph::Line({
         'x'         => $x_coord,
         'y'         => $y_coord,
         'width'     => $length,
         'height'    => $height,
         'colour'    => 'mediumblue',
         'zindex'    => 0,
      });
      $self->push($dbr);

      my $score = new Sanger::Graphics::Glyph::Circle({
          'x'        => $x_coord + ($length*0.55),
          'y'        => $y_coord +($height*0.55),
          'diameter' => 5,
          'colour'   => 'red',
          'filled'   => 1,
          'zmenu'    => $zmenu_s,
      });
      $self->push($score);

    }
    
  }	   


  ## Draw scalebar ##

  my $label = new Sanger::Graphics::Glyph::Text({
     'x'         => 35,
     'y'         => $y,
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
        'height'    => 4,
        'colour'    => 'black',
        'zindex' => 1,
    });
    $self->push($tick);
  
   my $rel_text = new Sanger::Graphics::Glyph::Text({
     'x'         => $x_coord,
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


sub features {
  my ($self) = @_;
  my @temphistory = $self->{'container'};
  my $th = shift(@temphistory);
  my %history = %$th;
  my (%feature, %nodes, %branches, %label,  %yc);

  return \%feature;
}

sub init_label {
  my ($self) = @_;

#  return;
  my $text =  'ID History Tree';
  my $max_length = 18;
  if (length($text) > $max_length) {
      $text = substr($text, 0, 14). " ...";
  }
  $self->init_label_text( $text );
}



sub image_label { 
    my ($self, $f ) = @_; 
    #return $f->seqname(), $f->{type} || 'overlaid'; 
}

sub zmenu_node {
  my( $self, $archive_id ) = @_;

  my $param =  $archive_id->type eq 'Translation' ? 'peptide' : lc($archive_id->type);
  my $type = ucfirst $param; 
  my $id = $archive_id->stable_id .".". $archive_id->version;
  my $rel = $archive_id->release;
  my $assembly = $archive_id->assembly;  
  my $db = $archive_id->db_name;
  my $link = qq(<a href="idhistoryview?$param=$id">$id</a>);

  my $zmenu = { 
		caption         => $id,
                "10:$type: $link" =>'', 
                "20:Release: $rel" =>'',
                "30:Assembly: $assembly" =>'',
                "40:Last Database: $db" =>, 
	      };

#  warn Data::Dumper::Dumper($zmenu);

  return ($zmenu, $link) ;
}

sub zmenu_score {
  my( $self, $event) = @_;
  my $old = $event->old_ArchiveStableId;
  my $old_id = $old->stable_id .".".$old->version;
  my $new = $event->new_ArchiveStableId;
  my $s = $event->score;
  my $new_id = $new->stable_id ."." .$new->version;
  my $param =  $old->type eq 'Translation' ? 'peptide' : lc($old->type);
  my $old_link = qq(<a href="idhistoryview?$param=$old_id">$old_id</a>);
  my $param2 =  $new->type eq 'Translation' ? 'peptide' : lc($new->type);
  my $new_link = qq(<a href="idhistoryview?$param2=$new_id">$new_id</a>);
  if ($s == 0){$s ="Unknown";} 

   my $zmenu = {
                 caption  => 'Similarity Match',
                 "10:Old Gene: $old_link" =>'',
                 "20:New Gene: $new_link"=>'',
                 "30:Score: $s" => '', 
               };

  return $zmenu;
}

1;
