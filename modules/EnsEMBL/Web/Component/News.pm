package EnsEMBL::Web::Component::News;

### Contains methods to output components of news pages

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

use strict;
use warnings;
no warnings "uninitialized";

@EnsEMBL::Web::Component::News::ISA = qw( EnsEMBL::Web::Component);

##-----------------------------------------------------------------
## NEWSVIEW COMPONENTS    
##-----------------------------------------------------------------

sub select_news {
### Standard form wrapper - see select_news_form, below
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form( 'select_news' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub select_news_form {
### Creates a Form object and adds elements with which to select news stories 
### by release, species or category
  my( $panel, $object ) = @_;
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'select_news', "/$species/$script", 'post' );

  my @rel_values;
  if ($species eq 'Multi') {
    
## do species dropdown
    my %all_species = %{$object->current_spp};
    my @sorted = sort {$all_species{$a} cmp $all_species{$b}} keys %all_species;
    my @spp_values = ({'name'=>'All species', 'value'=>'0'});
    foreach my $id (@sorted) {
        my $name = $all_species{$id};
        push (@spp_values, {'name'=>$name,'value'=>$id});
    }
    $form->add_element(
        'type'     => 'DropDown',
        'select'   => 'yes',
        'required' => 'yes',
        'name'     => 'species_id',
        'label'    => 'Species',
        'values'   => \@spp_values,
        'value'    => '0',
    );
    @rel_values = ({'name'=>'All releases', 'value'=>'all'});
  }

## do releases dropdown
  my @releases = @{$object->valid_rels};
  foreach my $rel (@releases) {
    my $id = $$rel{'release_id'};
    my $date = $$rel{'short_date'};
    push (@rel_values, {'name'=>"Release $id ($date)",'value'=>$id});
  }

  my $required = $species eq 'Multi' ? 'no' : 'yes';
    
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'yes',
    'required' => $required,
    'name'     => 'release_id',
    'label'    => 'Release',
    'values'   => \@rel_values,
    'value'    => '0',
  );

## do category dropdown
  my @cats = @{$object->all_cats};
  my @cat_values = ({'name'=>'All', 'value'=>'0'});
  foreach my $cat (@cats) {
    my $name = $$cat{'news_category_name'};
    my $id = $$cat{'news_category_id'};
    push(@cat_values, {'name'=>$name, 'value'=>$id});
  }
  $form->add_element(
    'type'     => 'DropDown',
    'required' => 'yes',
    'name'     => 'news_category_id',
    'label'    => 'Category',
    'values'   => \@cat_values,
    'value'    => '0',
  );

## rest of form
  my %all_spp = reverse %{$object->all_spp};
  my $sp_id = $all_spp{$species};
  $form->add_element('type' => 'Hidden', 'name' => 'species', 'value' => $sp_id);
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Go');

  return $form;
}

sub no_data {
### Creates a user-friendly error message for user queries that produce no results
  my( $panel, $object ) = @_;

  my $sp_id = $object->param('species_id');
  my $spp = $object->all_spp;
  my $sp_name = $$spp{$sp_id};
  $sp_name =~ s/_/ /g;

  my $rel_id = $object->param('release_id');
  my $releases = $object->releases;
  my $rel_no;
  foreach my $rel_array (@$releases) {
    $rel_no = $$rel_array{'release_number'} if $$rel_array{'release_id'} == $rel_id;
  }

  my $html = "<p>Sorry, <i>$sp_name</i> was not present in Ensembl Release $rel_no. Please try again.</p>";

  $panel->print($html);
  return 1;
}

sub show_news {
### Outputs a list of all the news stories selected by a user query; releases and/or categories
### are separated by headings where appropriate
  my( $panel, $object ) = @_;
  my $sp_dir = $object->species;
  (my $sp_title = $sp_dir) =~ s/_/ /;

  my $html;
  my $prev_cat = 0;
  my $prev_rel = 0;
  my $rel_selected = $object->param('release_id') || $object->param('rel');

## Get lookup hashes
  my $releases = $object->releases;
  my %rel_lookup;
  foreach my $rel_array (@$releases) {
    $rel_lookup{$$rel_array{'release_id'}} = $rel_array->{'full_date'};
  }
  my $cats = $object->all_cats;
  my %cat_lookup;
  foreach my $cat_array (@$cats) {
    $cat_lookup{$$cat_array{'news_category_id'}} = $cat_array->{'news_category_name'};
  }
  my $spp = $object->all_spp;
  my %sp_lookup = %$spp;
  if ($sp_dir eq 'Multi' && $object->param('species')) {
    $sp_dir = $sp_lookup{$object->param('species')};
  }

  ## Do title
  if ($rel_selected && $rel_selected ne 'all') {
    if ($rel_selected eq 'current') {
      $rel_selected = $object->species_defs->ENSEMBL_VERSION; 
    }
    my $rel_date = $rel_lookup{$rel_selected};
    $rel_date =~ s/^(-|\w)*\s//g;
    $html .= "<h2>Release $rel_selected News $rel_date</h2>";
  }

  my @generic_items = @{$object->generic_items};
  my @species_items = @{$object->species_items};

## sort the news items
  my ($all_sorted, $gen_sorted, $sp_sorted);
  if ($sp_dir eq 'Multi' || $rel_selected eq 'all') {
    my @all_items = (@generic_items, @species_items);
    $all_sorted = $object->sort_items(\@all_items);
  }
  else {
    $gen_sorted = $object->sort_items(\@generic_items);
    $sp_sorted  = $object->sort_items(\@species_items);
  }
## output sorted news
  my @sections;
  if ($sp_dir eq 'Multi') {
    @sections = ("Ensembl News");
  }
  elsif ($rel_selected eq 'all') {
    @sections = ("$sp_title News");
  }
  else {
    @sections = ("$sp_title News", "Other News");
  }
  for (my $i=0; $i<scalar(@sections); $i++) {
    my ($header, $current_items);
    if ($sp_dir eq 'Multi' || $rel_selected eq 'all') {
      $current_items = $all_sorted;
    }
    else {
      $header = $sections[$i];
      $current_items = $i == 0 ? $sp_sorted : $gen_sorted;
    }
    my $prev_sp = 0;
    my $prev_count = 0;
    my $ul_open = 0;
    for (my $i=0; $i<scalar(@$current_items); $i++) {
      my %item = %{$$current_items[$i]};
      next if $item{'status'} ne 'news_ok';
      my $item_id = $item{'news_item_id'};
      my $title = $item{'title'};
      my $content = $item{'content'};
      my $release_id = $item{'release_id'};
      my $rel_date = $rel_lookup{$release_id};
      $rel_date =~ s/.*\(//g;
      $rel_date =~ s/\)//g;
      my $news_cat_id = $item{'news_category_id'};
      my $cat_name = $cat_lookup{$news_cat_id};
      my $species = $item{'species'};
      my $sp_count = $item{'sp_count'};

      ## Release number (only needed for big multi-release pages)
      if (!$object->param('rel') && $prev_rel != $release_id) {
        $html .= qq(<h2>Release $release_id News ($rel_date)</h2>\n);
        $prev_cat = 0;
      }

      ## is it a new category?
      if ($prev_cat != $news_cat_id) {
        $html .= _output_cat_heading($news_cat_id, $cat_name, $rel_selected);
      }

      ## show list of affected species on main news page 
      if ($sp_dir eq 'Multi') {
        my $sp_str = '';
        if (ref($species) eq 'ARRAY' && scalar(@$species)) {
          for (my $j=0; $j<scalar(@$species); $j++) {
            $sp_str .= ', ' unless $j == 0;
            (my $sp_name = $sp_lookup{$$species[$j]}) =~ s/_/ /g;
            $sp_str .= "<i>$sp_name</i>";
          }
        }
        else {
          $sp_str = 'all species';
        }
        $title .= qq# <span style="font-weight:normal">($sp_str)</span>#;
      }
    
      ## wrap each record in nice XHTML
      $html .= _output_story($title, $content, $item_id);

      ## keep track of where we are!
      $prev_rel = $release_id;
      $prev_cat = $news_cat_id;
    }
  }

  $panel->print($html);
  return 1;
}

sub _output_cat_heading {
### "Private" method used by show_news (above) to format headers
    my ($cat_id, $cat_name, $release) = @_;
    my $anchor = $release eq 'all' ? '' : qq( id="cat$cat_id") ;
    my $html = qq(<h3 class="boxed"$anchor>$cat_name</h3>\n);
    return $html;
}

sub _output_story {
### "Private" method used by show_news (above) to format stories
    my ($title, $content, $id) = @_;
    
    my $html = qq(<h4 id="news_$id">$title</h4>\n);
    if ($content !~ /^</) { ## wrap bare content in a <p> tag
        $content = "<p>$content</p>";
    }
    $html .= $content."\n\n";
    
    return $html;
}

1;


