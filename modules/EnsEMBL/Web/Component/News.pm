package EnsEMBL::Web::Component::News;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

use strict;
use warnings;
no warnings "uninitialized";

@EnsEMBL::Web::Component::News::ISA = qw( EnsEMBL::Web::Component);

#-----------------------------------------------------------------
# NEWSVIEW COMPONENTS    
#-----------------------------------------------------------------

sub select_news {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form( 'select_news' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub select_news_form {
  my( $panel, $object ) = @_;
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'select_news', "/$species/$script", 'post' );
  my @releases = @{$object->valid_rels};
  my @rel_values;
  foreach my $rel (@releases) {
    my $id = $$rel{'release_id'};
    my $date = $$rel{'short_date'};
    push (@rel_values, {'name'=>"Release $id ($date)",'value'=>$id});
  }
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'yes',
    'required' => 'yes',
    'name'     => 'release_id',
    'label'    => 'Release',
    'values'   => \@rel_values,
    'value'    => '0',
  );

  my @cats = @{$object->all_cats};
  my @cat_values = ({'name'=>'All', 'value'=>'0'});
  foreach my $cat (@cats) {
    my $name = $$cat{'news_cat_name'};
    my $id = $$cat{'news_cat_id'};
    push(@cat_values, {'name'=>$name, 'value'=>$id});
  }
  $form->add_element(
    'type'     => 'DropDown',
    'required' => 'yes',
    'name'     => 'news_cat_id',
    'label'    => 'Category',
    'values'   => \@cat_values,
    'value'    => '0',
  );

  my %all_spp = reverse %{$object->all_spp};
  my $sp_id = $all_spp{$species};
  $form->add_element('type' => 'Hidden', 'name' => 'species', 'value' => $sp_id);
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Go');

  return $form;
}

sub show_news {
  my( $panel, $object ) = @_;
  my $sp_dir = $object->species;
  my $html;
  my $prev_cat = 0;
  my $prev_rel = 0;

  my @items = @{$object->items};
  my $releases = $object->releases;
  my %rel_lookup;
  foreach my $rel_array (@$releases) {
    $rel_lookup{$$rel_array{'release_id'}} = $$rel_array{'full_date'};
  }
  my $cats = $object->all_cats;
  my %cat_lookup;
  foreach my $cat_array (@$cats) {
    $cat_lookup{$$cat_array{'news_cat_id'}} = $$cat_array{'news_cat_name'};
  }
  my $spp = $object->all_spp;
  my %sp_lookup = %$spp;

  # Do custom sort of data news
  # 1. Sort into data and non-data news
  my (@sp_data, @other);
  for (my $i=0; $i<scalar(@items); $i++) {
    my $item_ref = ${$object->items}[$i];
    my %item = %$item_ref;
    if ($item{'news_cat_id'} == 2) {
        my $sp_count = $item{'sp_count'};
        if ($sp_count && $sp_count < 2) {
            push (@sp_data, $item_ref);
        }
        else {
            push (@other, $item_ref);
        }
    }
    else {
        push (@other, $item_ref);
    }
  }
  # 2. Sort single-species data by species
  my @sorted_data = sort
                    { $a->{'species'}[0] <=> $b->{'species'}[0] }
                    @sp_data;
  # 3. Merge news items back into single array
  my @sorted_items = (@sorted_data, @other);

  my $prev_sp = 0;
  my $prev_count = 0;
  for (my $i=0; $i<scalar(@sorted_items); $i++) {
    my %item = %{$sorted_items[$i]};
    my $item_id = $item{'news_item_id'};
    my $title = $item{'title'};
    my $content = $item{'content'};
    my $release_id = $item{'release_id'};
    my $rel_date = $rel_lookup{$release_id};
    $rel_date =~ s/.*\(//g;
    $rel_date =~ s/\)//g;
    my $news_cat_id = $item{'news_cat_id'};
    my $cat_name = $cat_lookup{$news_cat_id};
    my $species = $item{'species'};
    my $sp_count = $item{'sp_count'};
    my $sp_id;
    if (ref($species)) {
        $sp_id = ${$species}[0];
    }
    elsif ($species) {
        $sp_id = $species;
    }

    if ($prev_rel != $release_id) {
        $html .= qq(<h2>Release $release_id ($rel_date)</h2>\n);
        $prev_cat = '';
    }

    # separate data news into species and generic
    if ($sp_dir eq 'Multi' && $prev_cat == 0) {
        $html .= qq(<h3 class="boxed">Species News</h3>\n);
    }
    else {
        if ( ($prev_cat != $news_cat_id) || ($sp_dir eq 'Multi' && $sp_count != 1 && $prev_count == 1) ) {
            if ($news_cat_id == 2) {
                $html .= "</ul>\n\n";
            }
            $html .= qq(<h3 class="boxed">$cat_name</h3>\n);
        }
    }
    if ($sp_dir eq 'Multi' && $news_cat_id == 2 && $sp_count && $sp_count < 2) {
        unless ($sp_id == $prev_sp) {
            unless ($prev_sp == 0) { $html .= "</ul>\n\n" }
            (my $sp_name = $sp_lookup{$sp_id}) =~ s/_/ /g;
            $html .= qq(<h4 id="item$item_id"><i>$sp_name</i></h4>\n\n<ul class="spaced">\n);
        }
        $html .= qq(<li><strong>$title</strong><br />$content</li>\n);
    }
    else {
        $html .= "<h4>$title</h4><p>$content</p>";
    }
    #$html .= qq(<p>Species count = $sp_count</p>);

    $prev_rel = $release_id;
    $prev_cat = $news_cat_id;
    $prev_sp = $sp_id;
    $prev_count = $sp_count;
  }

  $panel->print($html);
  return 1;
}

#-----------------------------------------------------------------
# NEWSDBVIEW COMPONENTS    
#-----------------------------------------------------------------

sub select_to_edit {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if ($object->param('status') eq 'saved') {
    $html .= "<p>Thank you. Your changes have been saved to the database.</p>";
  }

  $html .= $panel->form( 'select_item' )->render();
  $html .= $panel->form( 'select_release' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;

}

sub select_item_only {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  $html .= $panel->form( 'select_item' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;

}

sub select_to_add {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if ($object->param('status') eq 'saved') {
    $html .= "<p>Thank you. The new article has been saved to the database.</p>";
  }

  $html .= $panel->form( 'select_release' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;

}

sub select_item_form {
  my( $panel, $object ) = @_;
  my $script = $object->script;
  my $species = $object->species;
  my $form = EnsEMBL::Web::Form->new( 'select_item', "/$species/$script", 'post' );
  
  # create array of release numbers, species and story titles
  my @items = @{$object->items};
  my %all_spp = %{$object->all_spp};
  my @all_rels = @{$object->releases};
  if (scalar(@items) > 0 ) { # sanity check!

    my @item_values;
    foreach my $item (@items) {
        my %item = %$item;
        my $code = $item{'news_item_id'};
        my $species_count = 0; 
        if (ref($item{'species'})) {
            $species_count = scalar(@{$item{'species'}});
        }
        my $sp_name;
        if ($species_count != 1) {
            $sp_name = 'multi-species';
        }
        else {
            my @sp_array = @{$item{'species'}};
            $sp_name = $all_spp{$sp_array[0]};
        }
        my $release_number;
        foreach my $rel (@all_rels) {
            if ($item{'release_id'} == $$rel{'release_id'}) {
                $release_number = $$rel{'release_number'};
            }
        }
        my $name = 'Rel '.$release_number.' - '.$item{'title'}." ($sp_name)";
        push (@item_values, {'name'=>$name,'value'=>$code});
    }
 
    $form->add_element( 'type' => 'SubHeader', 'value' => 'Select a news item from the latest release');
    $form->add_element( 'type' => 'Information', 'value' => '(to add an item, click on the menu link, left)');
    $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'news_item_id',
    'label'    => 'News item',
    'values'   => \@item_values,
  );
    $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Edit');
  }
  else {
    $form->add_element( 'type' => 'SubHeader', 'value' => 'Release '.$object->param('release_id'));
    $form->add_element( 'type' => 'Information', 'value' => 'There are currently no news items for this release. Please try another one.');
  }  
  return $form ;
}

sub select_release_form {
  my( $panel, $object ) = @_;
  my $script = $object->script;
  my $species = $object->species;
  
  # create array of release numbers and dates
  my @releases = @{$object->releases};
  my @rel_values;
  foreach my $rel (@releases) {
    my $id = $$rel{'release_id'};
    my $text = 'Release '.$$rel{'release_number'}.', '.$$rel{'short_date'};
    push (@rel_values, {'name'=>$text,'value'=>$id});
  }
 
  my $form = EnsEMBL::Web::Form->new( 'select_item', "/$species/$script", 'post' );
  
  $form->add_element( 'type' => 'SubHeader', 'value' => 'Select a release');
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'release_id',
    'label'    => 'Release',
    'values'   => \@rel_values,
  );
  $form->add_element( 'type' => 'Hidden', 'name' => 'action', 'value' => $object->param('action'));

  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Next');
  return $form;
}

#-----------------------------------------------------------------

sub item_form {
                                                                                
  my ($form, $object) = @_;
  my ($id, $name, $date);
                                                                                
  # set default values for form
  my ($title, $content, $release_id);
  $release_id = $object->param('release_id') || $object->species_defs->ENSEMBL_VERSION;
  my $news_cat_id = 2; # data
  my $species = []; # applies to all species
  my $priority = 0;

  if (scalar(@{$object->items}) == 1 && $object->param('action') ne 'add') { # have already selected a single item to edit
    my %item = %{${$object->items}[0]};
    $title = $item{'title'};
    $content = $item{'content'};
    $release_id = $item{'release_id'};
    $news_cat_id = $item{'news_cat_id'};
    $species = $item{'species'};
    $priority = $item{'priority'};
  }

  # create array of release names and values
  my @releases = @{$object->releases};
  my @rel_values;
  foreach my $release (@releases) {
    $id = $$release{'release_id'};
    $date = $$release{'release_number'}.' ('.$$release{'short_date'}.')';
    push (@rel_values, {'name'=>$date,'value'=>$id});
  }
                                                                                
  # create array of valid species names and values
  my %valid_species = %{$object->valid_spp};
  my @sorted = sort {$valid_species{$a} cmp $valid_species{$b}} keys %valid_species;
  my @spp_values;
  foreach my $id (@sorted) {
    my $name = $valid_species{$id};
    push (@spp_values, {'name'=>$name,'value'=>$id});
  }

  # create array of category names and values
  my @categories = @{$object->all_cats};
  my @cat_values;
  foreach my $cat (@categories) {
    $id = $$cat{'news_cat_id'};
    $name = $$cat{'news_cat_name'};
    push (@cat_values, {'name'=>$name,'value'=>$id});
  }
                                                                                
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'release_id',
    'label'    => 'Release',
    'values'   => \@rel_values,
    'value'    => $release_id,
  );
  $form->add_element('type'=>'Information', 'value'=>'For an item that applies to all current species,
leave the checkboxes blank');
  $form->add_element(
    'type'     => 'MultiSelect',
    'required' => 'yes',
    'name'     => 'species',
    'label'    => 'Species',
    'values'   => \@spp_values,
    'value'    => $species,
  );
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'news_cat_id',
    'label'    => 'News Category',
    'values'   => \@cat_values,
    'value'    => $news_cat_id,
  );
  $form->add_element(
    'type'     => 'Int',
    'required' => 'yes',
    'name'     => 'priority',
    'label'    => 'Priority [0-5]',
    'value'    => $priority,
    'size'     => '1'
  );
  $form->add_element(
    'type'      => 'String',
    'name'      => 'title',
    'label'     => 'Title',
    'value'     => $title
  );
   $form->add_element(
    'type'   => 'Text',
    'name'   => 'content',
    'label'  => 'Content',
    'value'  => $content,
  );
  $form->add_element( 'type' => 'Hidden', 'name' => 'update', 'value' => 'yes');

}

sub edit_item {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= qq(<p><strong>Important note</strong>: This form presents the available
species for the release currently associated with this record. If you wish to change 
this item to refer to a different release, you should do this first and save your changes, 
then make any required changes to the associated species.</p>);
  $html .= $panel->form( 'edit_item' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
                                                                                
}

sub edit_item_form {
                                                                                
  my( $panel, $object ) = @_;
  my $species = $object->species;
  my $script = $object->script;
  my $id = $object->param('news_item_id');
                                                                                
  my $form = EnsEMBL::Web::Form->new( 'edit_item', "/$species/$script", 'post' );
  $form->add_element( 'type' => 'SubHeader', 'value' => 'Edit a news item');
  item_form($form, $object);
  $form->add_element( 'type' => 'Hidden', 'name' => 'news_item_id', 'value' => $id);
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Preview');
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Save Changes');
  return $form ;
}

sub add_item {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form( 'add_item' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
                                                                                
}

sub add_item_form {
                                                                                
  my( $panel, $object ) = @_;
  my $species = $object->species;
  my $script = $object->script;
                                                                                
  my $form = EnsEMBL::Web::Form->new( 'add_item', "/$species/$script", 'post' );
  $form->add_element( 'type' => 'SubHeader', 'value' => 'Add a news item');
  item_form($form, $object);
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Preview');
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Save Changes');
  return $form ;
}

#-----------------------------------------------------------------

sub preview_item {
  my ( $panel, $object ) = @_;
  my %all_species = %{$object->all_spp};
  my @releases = @{$object->releases};
                                                                                
  my %item = %{@{$object->items}[0]};
  my $title = $item{'title'};
  my $content = $item{'content'};
  my $release_id = $item{'release_id'};
  my $news_cat_name = $item{'news_cat_name'};
  my $species = $item{'species'};
  my $priority = $item{'priority'};
 
  my $species_list;
  if (scalar(@$species) > 0) {
    $species_list = '<ul>';
    foreach my $sp (@$species) {
        my $sp_name = $all_species{$sp};
        $species_list .= "<li>$sp_name</li>";
    }
    $species_list .= '</ul>';
  }
  else {
    $species_list = '<p><strong>All species</strong></p>';
  }

  my $release_number;
  foreach my $rel (@releases) {
    if ($release_id == $$rel{'release_id'}) {
        $release_number = $$rel{'release_number'};
    }
  }

  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= qq(<p><strong>Release $release_number</strong></p>
<h3>$news_cat_name</h3>
<h4>$title</h4>
<p>$content</p>
<p class="center">* * * * *</p>
<p><strong>Priority: $priority</strong></p>
<p>This item will be included in the news for:</p>
$species_list
);

  $html .= $panel->form( 'preview_item' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;

}

sub preview_item_form {
                                                                                
  my ($panel, $object) = @_;
  my $script = $object->script;
  my $species = $object->species;

  my $form = EnsEMBL::Web::Form->new( 'preview_item', "/$species/$script", 'post' );
  
  my %item = %{${$object->items}[0]};
  my $content = $item{'content'};
  $content =~ s/"/&quot;/g;

  $form->add_element( 'type' => 'Hidden', 'name' => 'update', 'value' => 'yes');
  $form->add_element( 'type' => 'Hidden', 'name' => 'news_item_id', 'value' => $item{'news_item_id'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'release_id', 'value' => $item{'release_id'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'title', 'value' => $item{'title'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'content', 'value' => $content);
  $form->add_element( 'type' => 'Hidden', 'name' => 'news_cat_id', 'value' => $item{'news_cat_id'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'news_cat_name', 'value' => $item{'news_cat_name'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'priority', 'value' => $item{'priority'});
  foreach my $sp (@{$item{'species'}}) {
    $form->add_element( 'type' => 'Hidden', 'name' => 'species', 'value' => $sp);
  }
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Edit');
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Save Changes');
  return $form ;
}

1;
