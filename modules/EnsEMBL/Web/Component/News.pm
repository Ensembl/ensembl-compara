package EnsEMBL::Web::Component::News;

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

## rest of form
  my %all_spp = reverse %{$object->all_spp};
  my $sp_id = $all_spp{$species};
  $form->add_element('type' => 'Hidden', 'name' => 'species', 'value' => $sp_id);
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Go');

  return $form;
}

sub no_data {
  my( $panel, $object ) = @_;

## get species and release so we can give a friendly error message :)
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

## return the message
  my $html = "<p>Sorry, <i>$sp_name</i> was not present in Ensembl Release $rel_no. Please try again.</p>";

  $panel->print($html);
  return 1;
}

sub show_news {
  my( $panel, $object ) = @_;
  my $sp_dir = $object->species;
  (my $sp_title = $sp_dir) =~ s/_/ /;

  my $html;
  my $prev_cat = 0;
  my $prev_rel = 0;
  my $rel_selected = $object->param('release_id') || $object->param('rel');

  if ($rel_selected) {
    $html .= "<h2>Release $rel_selected</h2>";
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

## Get lookup hashes
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
  if ($sp_dir eq 'Multi' && $object->param('species')) {
    $sp_dir = $sp_lookup{$object->param('species')};
  }

## output sorted news
  my @sections;
  if ($sp_dir eq 'Multi') {
    @sections = ("Ensembl News");
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
      next if $item{'status'} ne 'live';
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

      ## Release number (only needed for big multi-release pages)
      if (!$object->param('rel') && $prev_rel != $release_id) {
        $html .= qq(<h2>Release $release_id ($rel_date)</h2>\n);
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
      $html .= _output_story($title, $content);

      ## keep track of where we are!
      $prev_rel = $release_id;
      $prev_cat = $news_cat_id;
    }
  }

  $panel->print($html);
  return 1;
}

sub _output_cat_heading {
    my ($cat_id, $cat_name, $release) = @_;
    my $anchor = $release eq 'all' ? '' : qq( id="cat$cat_id") ;
    my $html = qq(<h3 class="boxed"$anchor>$cat_name</h3>\n);
    return $html;
}

sub _output_story {
    my ($title, $content) = @_;
    
    my $html = "<h4>$title</h4>\n";
    if ($content !~ /^</) { ## wrap bare content in a <p> tag
        $content = "<p>$content</p>";
    }
    $html .= $content."\n\n";
    
    return $html;
}

1;

__END__
                                                                                
=head1 Ensembl::Web::Component::News
                                                                                
=head2 SYNOPSIS
                                                                                
This package is called from a Configuration object
                                                                                
    use EnsEMBL::Web::Component::News;
                                                                                
For each component to be displayed, you need to create an appropriate panel object and then add the component. The description of each component indicates the usual Panel subtype, e.g. Panel::Image.

For examples of how to use the components, see EnsEMBL::Web::Configuration::News
                                                                                
=head2 DESCRIPTION
                                                                                
This class consists of methods for displaying Ensembl news stories as XHTML. Current components include forms for updating the database, forms for selecting news stories, and a component to output the stories selected.

=head2 METHODS

Except where indicated, all methods take the same two arguments, a Document::Panel object and a Proxy::Object object (data). In general components return true on completion. If true is returned and the components are chained (see notes in Ensembl::Web::Configuration) then the subsequence components are ignored; if false is returned any subsequent components are executed.

=head3 B<METHODS FOR SELECTING & DISPLAYING NEWS>
                                                                                
=head4 B<select_news>
                                                                                
Description: Wraps the select_news_form (see below) in a DIV and passes the HTML back to the Panel::Image object for rendering 

=head4 B<select_news_form>
                                                                                
Description: Creates a Form object and adds widgets to select release, species, and/or news category

Returns:    An Ensembl::Web::Document::Form object

=head4 B<no_data>
                                                                                
Description: method to be called if no news items can be found for the user's chosen criteria. It passes an XHTML error message back to the Panel::Image object for rendering

=head4 B<show_news>
                                                                                
Description: method to be called if news items are available. Formats the available stories, sorted by release and category, and passes the resulting XHTML back to the Panel::Image object for rendering

=head4 B<_output_cat_heading>
                                                                                
Description: Private method for formatting a category heading

Arguments:  Category ID (integer), category name (string)

Returns:    string (XHTML)

=head4 B<_output_story>
                                                                                
Description: Private method for formatting an individual news item

Arguments:  Story title (string), story content (string)

Returns:    string (XHTML)

=head3 B<METHODS FOR CREATING A DB INTERFACE>

The next three methods are form wrappers which assemble the appropriate sub-forms and pass the resulting XHTML back to the Panel::Image object for rendering
                                                                                
=head4 B<select_to_add>

Description: Includes a confirmation message if the user has successfully completed a previous database insertion, then displays a select_release form (below) as Step 1 of the insertion process.

=head4 B<select_to_edit>

Description: Includes a confirmation message if the user has successfully completed a previous database update, then displays a select_item form showing stories for the current release, plus a select_release form in case the user wishes to correct an old item of news.

=head4 B<select_item_only>
                                                                                
Description: Displays the select_item form for a chosen release, e.g. as Step 2 of the insertion process.

=head4 B<select_item_form>
                                                                                
Description: Creates a small form with a dropdown box containing a list of news item for a given release

Returns:    An Ensembl::Web::Document::Form object

=head4 B<select_release_form>
                                                                                
Description: Creates a small form with a dropdown box containing a list of releases

Returns:    An Ensembl::Web::Document::Form object

The next 5 methods create the form used to either add or edit a news item

=head4 B<add_item>
                                                                                
Description:  Wraps the add_item_form (see below) in a DIV and passes the HTML back to the Panel::Image object for rendering

=head4 B<edit_item>
                                                                                
Description:  Wraps the edit_item_form (see below) in a DIV and passes the HTML back to the Panel::Image object for rendering

=head4 B<add_item_form>
                                                                                
Description: Creates a Form object, adds the _item_form widgets (see below) plus appropriately-labelled submit buttons

Returns:    An Ensembl::Web::Document::Form object

=head4 B<edit_item_form>
                                                                                
Description: Creates a Form object, adds the _item_form widgets (see below) plus appropriately-labelled submit buttons

Returns:    An Ensembl::Web::Document::Form object

=head4 B<_item_form>
                                                                                
Description: Adds a set of form widgets (for either adding or updating a news item) to an Ensembl::Web::Document::Form object

Returns:    true

The final set of interface components allow the user to preview an item before saving it to the database

=head4 B<preview_item>
                                                                                
Description: Displays the user's input as XHTML (so that any syntax errors can easily be spotted) and also creates a preview_item_form so that input can be passed along to the database update/insertion calls in the originating perl script 

=head4 B<preview_item_form>
                                                                                
Description: Creates a Form object consisting mainly of 'hidden' input plus a submit button

Returns:    An Ensembl::Web::Document::Form object

=head2 BUGS AND LIMITATIONS
                                                                                
The admin interface has been exhibiting an intermittent bug when forwarding via a CGI redirect (i.e. when saving new or edited data), but hopefully this has been fixed by always using /Multi as the 'species' directory :)
                                                                                                                                                              
=head2 AUTHOR
                                                                                
Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut

