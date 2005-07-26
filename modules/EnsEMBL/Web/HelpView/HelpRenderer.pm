package EnsEMBL::Web::HelpView::HelpRenderer;

=head1 NAME

EnsEMBL::Web::HelpView::HelpRenderer - renderer for the Ensembl helpdb editing
interface

=head1 SYNOPSIS

# create objects
my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new;
my $renderer = EnsEMBL::Web::HelpView::HelpRenderer->new($helpdb);

# print the page header
$renderer->print_header($helpdb->db_string;

=head1 DESCRIPTION

This object is a HTML renderer for the Ensembl helpdb editing interface.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use SpeciesDefs;

=head2 new

  Arg[1]      : EnsEMBL::Web::HelpView::HelpAdaptor - helpdb adaptor
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new;
                my $renderer = EnsEMBL::Web::HelpView::HelpRenderer->new($helpdb);
  Description : object constructor
  Return type : EnsEMBL::Web::HelpView::HelpRenderer
  Exceptions  : thrown when no EnsEMBL::Web::HelpView::HelpAdaptor is provided
  Caller      : general

=cut

sub new {
    my $class = shift;
    my $dba = shift || throw('You must provide a EnsEMBL::Web::HelpView::HelpAdaptor')
    ;
    my $self = {
        'species_defs'  => SpeciesDefs->new,
        'dba'           => $dba,
    };
    bless($self, $class);
    return $self;
}

=head2 print_header

  Arg[1]      : String $db_string - database identifier shown in header
  Arg[2]      : (optional) Boolean $onload - toggle preview onload javascript
  Example     : $renderer->print_header('help@ecs3:3307);
  Description : Prints http header, html header and left navigation menu
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_header {
    my ($self, $db_string, $onload) = @_;
    print "Content-type: text/html\n\n";

    my $logo_html = sprintf(
        qq(<img src="%s" height="%s" alt="%s" style="border: 0; padding-right: 20px; vertical-align: top;">),
        $self->{'species_defs'}->AUTHORITY_LOGO,          
        $self->{'species_defs'}->AUTHORITY_LOGO_HEIGHT,
        $self->{'species_defs'}->AUTHORITY_LOGO_ALT, 
    );

    # onload javascript for preview
    my $onload_html = "";
    if ($onload) {
        $onload_html = qq( onLoad="javascript:void(window.open('help_preview','help_preview','width=400,height=500,resizable,scrollbars'))");
    }

    print <<EOH;
<html>
  <head>
    <title>Ensembl HelpDB Editor</title>
    <link rel="stylesheet" type="text/css" href="@{[$self->{'species_defs'}->ENSEMBL_CSS]}">
  </head>
  <body style="margin: 0"$onload_html>
  <table border="0" width="100%" cellspacing="0" cellpadding="0">
    <tr>
      <td>$logo_html <span class="h1">HelpDB Editor</span></td>
    </tr>
    <tr>
      <td style="background-color: #EEEEEE; border-top: 1px solid black; border-bottom: 1px solid black; padding: 2px;">
        <b>Database:</b> $db_string
      </td>
    </tr>
  </table>
  <table border="0" width="100%">
    <tr>
      <td class="menu">
        <div class="menublock">
          <div class="menuheader">Articles</div>
          <div>
            <div class="submenu"><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=list_articles">List/edit/delete</a></div>
            <div class="submenu"><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=new_article">New</a></div>
          </div>
        </div>
        <div class="menublock">
          <div class="menuheader">Categories</div>
          <div>
            <div class="submenu"><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=list_categories">List/edit/delete</a></div>
            <div class="submenu"><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=new_category">New</a></div>
          </div>
        </div>
      </td>
      <td class="content">
EOH
}

=head2 print_footer

  Example     : $renderer->print_footer;
  Description : prints the html footer
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_footer {
    my $self = shift;
    my ($time) = @{[scalar(gmtime())]};
    print <<EOH;
      </td>
    </tr>
  </table>
  <table border="0" width="100%">
    <tr>
      <td class="background1">
        <a href="http://www.ensembl.org/ensemblpowered.html"><img src="/gfx/empowered.png" height="20" width="98" alt="Powered by Ensembl code" border="0"></a>
      </td>
      <td class="background1" align="right">
        $time
      </td>
    </tr>
  </table>
</body>
</html>
EOH
}

=head2 print_article_list

  Arg[1]      : listref of EnsEMBL::Web::HelpView::Articles
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new;
                my $renderer = EnsEMBL::Web::HelpView::HelpRenderer->new($helpdb);
                $renderer->print_article_list($helpdb->fetch_all_articles);
  Description : Prints a table of Ensembl help articles
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_article_list {
    my ($self, $articles) = @_;
    throw("You must provide a listref of EnsEMBL::Web::HelpView::Articles")
        unless $articles;

    # table header
    print <<EOH;
    <table class="multicol" width="100%">
      <tr>
        <th>
          Keyword
          <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=list_articles&order_by=keyword" title="order by keyword (ascending)"><img src="/gfx/helpview/arrow_up.gif" style="border: 0; vertical-align: middle" alt="ascending"></a><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=list_articles&order_by=keyword_desc" title="order by keyword (descending)"><img src="/gfx/helpview/arrow_down.gif" style="border: 0; vertical-align: middle" alt="descending"></a> 
        </th>
        <th>
          Title
          <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=list_articles&order_by=title" title="order by title (ascending)"><img src="/gfx/helpview/arrow_up.gif" style="border: 0; vertical-align: middle" alt="ascending"></a><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=list_articles&order_by=title_desc" title="order by title (descending)"><img src="/gfx/helpview/arrow_down.gif" style="border: 0; vertical-align: middle" alt="descending"></a> 
        </th>
        <th>
          Category
          <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=list_articles&order_by=category" title="order by category (ascending)"><img src="/gfx/helpview/arrow_up.gif" style="border: 0; vertical-align: middle" alt="ascending"></a><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=list_articles&order_by=category_desc" title="order by category (descending)"><img src="/gfx/helpview/arrow_down.gif" style="border: 0; vertical-align: middle" alt="descending"></a> 
        </th>
        <th>
          Action
        </th>
      </tr>
EOH

    # table row (article)
    my $ROW_HTML = qq(
      <tr class="%s">
        <td>%s</td>
        <td><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=edit_article&article_id=%s">%s</a></td>
        <td>%s</td>
        <td>
          <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=edit_article&article_id=%s" title="edit"><img src="/gfx/helpview/edit_icon.gif" alt="edit" border="0"></a>
          <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=delete_article&article_id=%s" title="delete"><img src="/gfx/helpview/delete_icon.gif" alt="delete" border="0"></a>
        </td>
      </tr>
    );
    
    # alternate background
    my @bg = ("background1", "");
    my $i = 1;

    foreach my $article (@{ $articles }) {
        # trim title
        if (length($article->title) > 30) {
            $article->title(substr($article->title, 0, 27) . "...");
        }

        printf(
            $ROW_HTML,
            $bg[$i % 2],
            $article->keyword,
            $article->article_id,
            $article->title,
            $article->category_name,
            $article->article_id,
            $article->article_id
        );

        $i++;
    }

    print qq(</table>);
}

=head2 print_article_form

  Arg[1]      : String $action - submit action (save_article|add_article)
  Arg[2]      : (optional) Int $id - article ID
  Arg[3]      : (optional) String $keyword - article keyword
  Arg[4]      : (optional) String $keyword_orig - original keyword (for data
                integrity check)
  Arg[5]      : (optional) String $title - article title
  Arg[6]      : (optional) String $content - article content
  Arg[7]      : (optional) Int $cat_id - category ID
  Example     : $renderer->print_article_form('add_article');
  Description : Prints a form for editing an existing help article or entering
                a new one.
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_article_form {
    my ($self, $action, $id, $keyword, $keyword_orig, $title, $content, $cat_id) = @_;
    my $cat_html = $self->category_pulldown($cat_id);

    print <<EOH;
<form name="article" action="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}" method="POST">
<input type="hidden" name="article_id" value="$id">
<input type="hidden" name="keyword_orig" value="$keyword_orig">
<input type="hidden" name="action" value="$action">
<input type="hidden" name="preview" value="">

<table class="hidden">
  <tr valign="top">
    <th align="left">Keyword</th>
    <td>
      <input type="text" name="keyword" value="$keyword" size="40">
    </td>
  </tr>
  <tr valign="top">
    <th align="left">Title</th>
    <td>
      <input type="text" name="title" value="$title" size="60">
    </td>
  </tr>
  <tr valign="top">
    <th align="left">Category</th>
    <td>
      $cat_html
    </td>
  </tr>
  <tr valign="top">
    <th align="left">Content</th>
    <td>
      <textarea name="content" cols="80" rows="30" wrap="virtual">$content</textarea>
    </td>
  </tr>
  <tr valign="top">
    <th></th>
    <td>
      <input type="button" name="submitButton" value="Preview" onclick="document.article.preview.value = '1'; document.article.submit();">
      <input type="button" name="submitButton" value="Save" onclick="document.article.submit();">
      <input type="button" name="submitButton" value="Cancel" onclick="history.back();">
    </td>
  </tr>
</table>
</form>
EOH

}

=head2 category_pulldown

  Arg[1]      : (optional) Int $cat_id - selected category ID
  Example     : print '<form method="POST>';
                print $renderer->category_pulldown(5);
                print '</form>';
  Description : Prints a select menu with all categories found in the help
                database. If a category ID is provided, the respective
                category is selected.
  Return type : String - html code
  Exceptions  : none
  Caller      : internal

=cut

sub category_pulldown {
    my ($self, $cat_id) = @_;
    my $categories = $self->{'dba'}->fetch_all_categories;
    my $html = qq(<select name="category_id">\n<option value=""></option>);
    foreach my $category (@{ $categories }) {
        $html .= "<option value=\"".$category->category_id."\"";
        if ($cat_id && ($cat_id == $category->category_id)) {
            $html .= " selected";
        }
        $html .= ">".$category->name."</option>\n";
    }
    $html .= qq(</select>);
    return $html;
}

=head2 print_delarticle_confirm

  Arg[1]      : Int $id - article ID
  Example     : unless ($cgi->param('confirmed')) {
                    $renderer->print_delarticle_confirm(1);
                }
  Description : Ask user to confirm deletion of an article
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_delarticle_confirm {
    my ($self, $id) = @_;
    print <<EOH;
<form name="article" action="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}" method="POST">
<input type="hidden" name="article_id" value="$id">
<input type="hidden" name="action" value="delete_article">
<input type="hidden" name="confirmed" value="1">

<p>Are you sure you want to delete the article with ID $id from the helpdb?</p>


<input type="button" name="submitButton" value="Cancel" onclick="history.back();">
<input type="button" name="submitButton" value="Delete" onclick="document.article.submit();">
</form>

EOH

}

=head2 print_preview

  Arg[1]      : String $title - article title
  Arg[2]      : String $content - article content
  Example     : $renderer->print_preview('Geneview', 'This is the content');
  Description : Writes an article for preview into a temporary file. This file
                is read by a popup window which is opened by an onload
                javascript.
  Return type : none
  Exceptions  : thrown when unable to write to temp file
  Caller      : general

=cut

sub print_preview {
    my ($self, $title, $content) = @_;
    my $TMPDIR = $self->{'species_defs'}->ENSEMBL_TMP_DIR;
    open PREFILE, ">$TMPDIR/help_preview.tmp" or die
        "Unable to open $TMPDIR/help_preview.tmp for writing: $!";
    print PREFILE qq(<h3>$title</h3>\n$content);
    close PREFILE;	
}

=head2 print_content_heading

  Arg[1]      : String $text - heading text
  Example     : $renderer->print_content_heading('Edit article');
  Description : Prints a content heading.
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_content_heading {
    my ($self, $text) = @_;
    print qq(<h3>$text</h3>);
}

=head2 print_content_text

  Arg[1]      : String $text - content text
  Example     : $renderer->print_content_text('Article updated successfully.');
  Description : Prints a content text.
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_content_text {
    my ($self, $text) = @_;
    print qq(<p>$text</p>);
}

=head2 print_warning

  Arg[1]      : String $text - warning text
  Example     : $renderer->print_warning('Keyword must be unique.');
  Description : Prints a warning.
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_warning {
    my ($self, $text) = @_;
    print qq(<p class="error">$text</p>);
}

=head2 print_category_list

  Arg[1]      : listref of EnsEMBL::Web::HelpView::Categories
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new;
                my $renderer = EnsEMBL::Web::HelpView::HelpRenderer->new($helpdb);
                $renderer->print_category_list($helpdb->fetch_all_categories);
  Description : Prints a table of help categories
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_category_list {
    my ($self, $categories) = @_;
    throw("You must provide a listref of EnsEMBL::Web::HelpView::Category")
        unless $categories;

    # table header
    print <<EOH;
    <table class="multicol" width="100%">
      <tr>
        <th>Category name</th>
        <th>Priority</th>
        <th>Action</th>
      </tr>
EOH

    # table rows (categories)
    my $ROW_HTML = qq(
      <tr class="%s">
        <td><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=edit_category&category_id=%s">%s</a></td>
        <td>%s</td>
        <td>
          <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=edit_category&category_id=%s" title="edit"><img src="/gfx/helpview/edit_icon.gif" alt="edit" border="0"></a>
          <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=delete_category&category_id=%s" title="delete"><img src="/gfx/helpview/delete_icon.gif" alt="delete" border="0"></a>
        </td>
      </tr>
    );

    # alternate background colors
    my @bg = ("background1", "");
    my $i = 1;

    foreach my $category (@{ $categories }) {
        printf(
            $ROW_HTML,
            $bg[$i % 2],
            $category->category_id,
            $category->name,
            $category->priority,
            $category->category_id,
            $category->category_id
        );
        $i++;
    }

    print qq(</table>);
}

=head2 print_category_form

  Arg[1]      : String $action - submit action (save_category|add_category)
  Arg[2]      : (optional) Int $id - category ID
  Arg[3]      : (optional) String $name - category name
  Arg[4]      : (optional) Int $priority - priority
  Example     : $renderer->print_category_form('add_category');
  Description : Prints a form for editing an existing help category or entering
                a new one.
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_category_form {
    my ($self, $action, $id, $name, $priority) = @_;

    print <<EOH;
<form name="category" action="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}" method="POST">
<input type="hidden" name="category_id" value="$id">
<input type="hidden" name="action" value="$action">

<table class="hidden">
  <tr valign="top">
    <th align="left">Category name</th>
    <td>
      <input type="text" name="name" value="$name" size="40">
    </td>
  </tr>
  <tr valign="top">
    <th align="left">Priority</th>
    <td>
      <input type="text" name="priority" value="$priority" size="10">
    </td>
  </tr>
  <tr valign="top">
    <th></th>
    <td>
      <input type="button" name="submitButton" value="Save" onclick="document.category.submit();">
      <input type="button" name="submitButton" value="Cancel" onclick="history.back();">
    </td>
  </tr>
</table>
</form>
EOH

}

=head2 print_delcategory_confirm

  Arg[1]      : Int $id - category ID
  Example     : unless ($cgi->param('confirmed')) {
                    $renderer->print_delcategory_confirm(1);
                }
  Description : Ask user to confirm deletion of a category
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub print_delcategory_confirm {
    my ($self, $id) = @_;
    print <<EOH;
<form name="category" action="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}" method="POST">
<input type="hidden" name="category_id" value="$id">
<input type="hidden" name="action" value="delete_category">
<input type="hidden" name="confirmed" value="1">

<p>Are you sure you want to delete the category with ID $id from the helpdb?</p>


<input type="button" name="submitButton" value="Cancel" onclick="history.back();">
<input type="button" name="submitButton" value="Delete" onclick="document.category.submit();">
</form>

EOH

}

1;

