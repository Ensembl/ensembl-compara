package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs two alternative tabbed panels for the Ensembl homepage
### 1) the "About Ensembl" blurb
### 2) A selection of news headlines, based on the user's settings or a default list

use strict;
use warnings;

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::DBSQL::NewsAdaptor;

{

sub render {

### Renders the HTML for two tabbed panels - blurb and news headlines

## JS tab-switching, plus Ensembl blurb
  my $html = qq(

<script language="javascript">
  function show_whatsnew() {
    document.getElementById('whatsnew').style.display = 'block';
    document.getElementById('whatsnew_tab').className = 'tab selected';
    document.getElementById('aboutensembl').style.display = 'none';
    document.getElementById('aboutensembl_tab').className = 'tab';
  }

  function show_aboutensembl() {
    document.getElementById('whatsnew').style.display = 'none';
    document.getElementById('whatsnew_tab').className = 'tab';
    document.getElementById('aboutensembl').style.display = 'block';
    document.getElementById('aboutensembl_tab').className = 'tab selected';
  }
</script>

<div class="box_tabs">
  <div class="tab selected" id="aboutensembl_tab">
    <a href="javascript:void(0);" onClick="show_aboutensembl();">About Ensembl</a>
  </div>
  <div class="tab" id="whatsnew_tab">
    <a href="javascript:void(0);" onClick="show_whatsnew();">What's new</a>
  </div>
  <br clear="all" />
  <div class="tab_content">
  <div class="tab_content_panel" id="aboutensembl">
<a href="http://www.ensembl.org">Ensembl</a> is a joint project between <a
   href="http://www.ebi.ac.uk">EMBL - EBI</a> and the <a
 href="http://www.sanger.ac.uk">Sanger Institute</a>
   to develop a software system which produces and maintains automatic
   annotation on selected eukaryotic genomes. Ensembl is primarily funded by
   the <a href="http://www.wellcome.ac.uk/">Wellcome Trust</a>.</p>

<p>This site provides <a href="/info/about/disclaimer.html" title="More information about free access">free access</a> to all the data and software from the Ensembl project.  Click on a species name to browse the data.</p>

<p>Access to all the data produced by the project, and to
   the software used to analyse and present it, is provided free and
   without constraints.  Some data and software may be subject to <a href="/info/about/disclaimer.html" title="More information about access restrictions">third-party constraints</a>.</p>
<p>For all enquiries, please <a href="/info/about/contact.html">contact the Ensembl HelpDesk</a> (<a
   href="mailto:helpdesk\@ensembl.org">helpdesk\@ensembl.org</a>).
  </div>
  <div class="tab_content_panel" id="whatsnew" style="display: none;">
<div class="species-news">
);

## News headlines

  my $species_defs = EnsEMBL::Web::SpeciesDefs->new();
  my $release_id = $species_defs->ENSEMBL_VERSION;
  my $user_id = $ENV{'ENSEMBL_USER_ID'};
  my $user = EnsEMBL::Web::Object::User->new({ id => $user_id });

  my $DB = $species_defs->databases->{'ENSEMBL_WEBSITE'};
  my $adaptor = EnsEMBL::Web::DBSQL::NewsAdaptor->new( $DB );
  my @headlines;

  ## get news headlines
  my $criteria = {'release'=>$release_id};
  if ($user_id > 0) {
    $html .= "<h4>Your Ensembl headlines</h4>";
    ## check for user filters
    my @filters = $user->news_records;
    ## Look up species ids and category ids for use in query
    foreach my $f (@filters) {
      if ($f->species && $f->species ne 'none') {
        my $species_id = $adaptor->fetch_species_id($f->species);
        $criteria->{'species'} = $species_id;
      }
      if ($f->topic && $f->topic ne 'none') {
        my $category_id = $adaptor->fetch_cat_id($f->topic);
        $criteria->{'category'} = $category_id;
      }
    }
  }
  @headlines = @{$adaptor->fetch_news_items($criteria, '', '5')};
  my %current_spp = %{$adaptor->fetch_species($release_id)};

  ## format news headlines
  foreach my $item (@headlines) {

    ## sort out species names
    my $species = $item->{'species'};
    my (@sp_ids, $sp_id, $sp_dir, $sp_name, $sp_count);
    if (ref($species)) {
      $sp_id = ${$species}[0];
      @sp_ids = @{$species};
    }
    else {
      $sp_id = $species;
      @sp_ids = ($sp_id);
    }
    if ($sp_id) {
      $sp_dir = $current_spp{$sp_id};
      $sp_count = scalar(@sp_ids);
      if ($sp_count > 1) {
        for (my $j=0; $j<$sp_count; $j++) {
          $sp_name .= ', ' unless $j == 0;
          my @name_bits = split('_', $current_spp{$sp_ids[$j]});
          $sp_name .= '<i>'.substr($name_bits[0], 0, 1).'. '.$name_bits[1].'</i>';
          }
        }
      else {
        ($sp_name = $sp_dir) =~ s/_/ /g;
        $sp_name = "<i>$sp_name</i>";
      }
    }
    else {
      $sp_dir = 'Multi';
      $sp_name = 'all species';
    }
 
    ## generate HTML
    $html .= '<p>';
    if ($sp_count == 1) {
      $html .= qq(<a href="/$sp_dir/"><img src="/img/species/thumb_$sp_dir.png" alt="" title="Go to the $sp_name home page" class="sp-thumb" height="30" width="30" /></a>);
    }
    else {
      $html .= qq(<img src="/img/ebang-30x30.png" alt="" class="sp-thumb" height="30" width="30" />);
    }

    $html .= sprintf(qq(<strong><a href="/%s/newsview?rel=%s#cat%s" style="text-decoration:none">%s</a></strong> (<i>%s</i>)</p>),
              $sp_dir, $release_id, $item->{'news_cat_id'}, $item->{'title'}, $sp_name);

  }

  $html .= "\n</div>\n";

  if ($ENV{'ENSEMBL_LOGINS'} && $user_id < 1) {
    $html .= qq(<a href="javascript:login_link();">Log in</a> to see customised news &middot; <a href="/common/register">Register</a>);
  }

  $html .= qq(
</div>
  <!-- common footer -->
  </div>
</div>

);

  return $html;
}

}

1;
