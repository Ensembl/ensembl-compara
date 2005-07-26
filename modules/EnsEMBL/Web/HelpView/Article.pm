package EnsEMBL::Web::HelpView::Article;

=head1 NAME

EnsEMBL::Web::HelpView::Article - object representing an Ensembl help article

=head1 SYNOPSIS

# create object
my $article = EnsEMBL::Web::HelpView::Article->new(
                -ARTICLE_ID     => 1,
                -KEYWORD        => 'geneview',
                -TITLE          => 'Geneview',
);

# set content
$article->content('This is the content');

=head1 DESCRIPTION

Simple object representing an Ensembl help article. Uses AUTOLOAD for
accessors.

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

use Bio::EnsEMBL::Utils::Argument qw(rearrange);

# allowed methods (for AUTOLOAD)
our %methods = map { $_ => 1 }
    qw(article_id keyword title content category_id category_name priority);

=head2 new

  Arg [-ARTICLE_ID]     : Int - article ID
  Arg [-KEYWORD]        : String - article keyword (for linking to article)
  Arg [-TITLE]          : String - article title
  Arg [-CONTENT]        : String - article content
  Arg [-CATEGORY_ID]    : Int - category ID
  Arg [-PRIORITY]       : Int - priority (for ordering)
  
  Example     : my $article = EnsEMBL::Web::HelpView::Article->new(
                    -ARTICLE_ID     => 1,
                    -KEYWORD        => 'geneview',
                    -TITLE          => 'Geneview',
                );
  Description : object constructor
  Return type : EnsEMBL::Web::HelpView::Article
  Exceptions  : none
  Caller      : general

=cut

sub new {
    my $caller = shift;
    my $class = ref($caller) || $caller;

    my ($article_id, $keyword, $title, $content, $category_id, $cat_name, $priority) = rearrange(['ARTICLE_ID', 'KEYWORD', 'TITLE', 'CONTENT', 'CATEGORY_ID', 'CATEGORY_NAME', 'PRIORITY'], @_);

    my $self = {
           'article_id'     => $article_id,
           'keyword'        => $keyword,
           'title'          => $title,
           'content'        => $content,
           'category_id'    => $category_id,
           'category_name'  => $cat_name,
           'priority'       => $priority,
    };
    bless($self, $class);
    return $self;
}

=head2 AUTOLOAD

  Arg[1]      : (optional) String/Object - attribute to set
  Example     : # setting a attribute
                $self->attr($val);
                # getting the attribute
                $self->attr;
                # undefining an attribute
                $self->attr(undef);
  Description : lazy function generator for getters/setters
  Return type : String/Object
  Exceptions  : none
  Caller      : general

=cut

sub AUTOLOAD {
    my $self = shift;
    my $attr = our $AUTOLOAD;
    $attr =~ s/.*:://;
    return unless $attr =~ /[^A-Z]/;
    die ("Invalid attribute method: $attr") unless $methods{$attr};
    no strict 'refs';
    *{$AUTOLOAD} = sub {
        $_[0]->{$attr} = $_[1] if (@_ > 1);
        return $_[0]->{$attr};
    };
    $self->{$attr} = shift if (@_);
    return $self->{$attr};
}

1;

