package EnsEMBL::Web::HelpView::HelpAdaptor;

=head1 NAME

EnsEMBL::Web::HelpView::HelpAdaptor - database adaptor for an Ensembl help
datebase

=head1 SYNOPSIS

# get a database adaptor
my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();

# fetch all help articles
my $articles = $helpdb->fetch_all_articles;

# fetch a single article by ID
my $article = $helpdb->fetch_article_by_id(17);

=head1 DESCRIPTION

This module is an interface to an Ensembl help database.

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

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::DBSQL::UserDB;
use EnsEMBL::Web::HelpView::Article;
use EnsEMBL::Web::HelpView::Category;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

our $USERDATATYPE_ID = 210;
our $SPECIES_DEFS;
BEGIN {
  $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new;
}


=head2 new

  Arg[1]      : String $class - class name to bless object into
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
  Description : object constructor
  Return type : EnsEMBL::Web::HelpView::HelpAdaptor
  Exceptions  : none
  Caller      : general

=cut

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);

    # get database handle (no lazy loading)
    $self->dbh;

    return $self;
}

=head2 dbh

  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                my $dbh = $helpdb->dbh;
                my $sth = $dbh->prepare('SELECT * FROM article');
  Description : Returns a database handle for the help db
  Return type : DBI database handle
  Exceptions  : thrown if no database connection
  Caller      : internal

=cut

use DBI;
sub dbh {
    my $self = shift;
    unless ($self->{'_dbh'}) {
        my $dbinfo = $SPECIES_DEFS->multidb->{'ENSEMBL_WEBSITE'};
        my $dbh = DBI->connect(
		"DBI:mysql:database=$dbinfo->{NAME};host=$dbinfo->{HOST};port=$dbinfo->{PORT}",
                $SPECIES_DEFS->ENSEMBL_WRITE_USER,
                $SPECIES_DEFS->ENSEMBL_WRITE_PASS );
        $self->{'_dbh'} = $dbh;

        # store database name, host and port
        $self->{'dbname'} = $dbinfo->{'NAME'};
        $self->{'host'} = $dbinfo->{'HOST'};
        $self->{'port'} = $dbinfo->{'PORT'};
    }
    return $self->{'_dbh'};
}

=head2 db_string

  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                print $helpdb->db_string;
  Description : Returns a string identifying the database you are connected to
                (format: DBNAME@HOST:PORT)
  Return type : String - the db identification string
  Exceptions  : none
  Caller      : general

=cut

sub db_string {
    my $self = shift;
    my $dbh = $self->dbh;
    my $db_string = $self->{'dbname'}.'@'.$self->{'host'}.':'.$self->{'port'};
    return $db_string;
}

=head2 fetch_all_articles

  Arg[1]      : (optional) String $order_by - sort order
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                my $articles = $helpdb->fetch_all_articles;
                foreach my $article (@{ $articles }) {
                    print $article->title . "\n";
                }
  Description : Fetches all help articles from the database
  Return type : listref of EnsEMBL::Web::HelpView::Articles
  Exceptions  : none
  Caller      : general

=cut

sub fetch_all_articles {
    my $self = shift;

    # get order_by from cgi param, then cookie, then default
    my $order_by = shift;
    my $userdb = EnsEMBL::Web::DBSQL::UserDB->new;
    unless ($order_by) {
        $order_by = $userdb->getConfig(
            $ENV{'ENSEMBL_FIRSTSESSION'},
            $USERDATATYPE_ID,
        );
    }
    $order_by ||= 'category';

    # store order_by in userdb
    $userdb->setConfig(
        Apache->request,
        $ENV{'ENSEMBL_FIRSTSESSION'} || undef,
        $USERDATATYPE_ID,
        $order_by,
    );
    
    my %order_map = (
        'keyword'       => 'keyword',
        'keyword_desc'  => 'keyword DESC',
        'title'         => 'title',
        'title_desc'    => 'title DESC',
        'category'      => 'name, keyword',
        'category_desc' => 'name DESC, keyword ASC',
    );
    my $sql = qq(
        SELECT
                a.article_id    as article_id,
                a.keyword       as keyword,
                a.title         as title,
                a.content       as content,
                a.category_id   as category_id,
                c.name          as category_name,
                c.priority      as priority
        FROM
                article a,
                category c
        WHERE   a.category_id = c.category_id
        ORDER BY $order_map{$order_by}
    );
    my $sth = $self->dbh->prepare($sql);
    $sth->execute;
    my @articles;
    while (my $row = $sth->fetchrow_hashref) {
        my $article = EnsEMBL::Web::HelpView::Article->new(
            -article_id     => $row->{'article_id'},
            -keyword        => $row->{'keyword'},
            -title          => $row->{'title'},
            -content        => $row->{'content'},
            -category_id    => $row->{'category_id'},
            -category_name  => $row->{'category_name'},
            -priority       => $row->{'priority'},
        );
        push @articles, $article;
    }
    return \@articles;
}

=head2 fetch_article_by_id

  Arg[1]      : Int $id - article ID
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                my $article = $helpdb->fetch_article_by_id(222);
                print $article->title . "\n";
  Description : Fetches an article by ID from the database
  Return type : EnsEMBL::Web::HelpView::Articles
  Exceptions  : none
  Caller      : general

=cut

sub fetch_article_by_id {
    my ($self, $id) = @_;
    throw("You must provide an article ID") unless $id;

    my $sql = qq(
        SELECT
                a.article_id    as article_id,
                a.keyword       as keyword,
                a.title         as title,
                a.content       as content,
                a.category_id   as category_id,
                c.name          as category_name,
                c.priority      as priority
        FROM
                article a,
                category c
        WHERE   a.article_id = $id
        AND     a.category_id = c.category_id
    );
    my $sth = $self->dbh->prepare($sql);
    $sth->execute;
    my $row = $sth->fetchrow_hashref;
    my $article = EnsEMBL::Web::HelpView::Article->new(
        -article_id     => $row->{'article_id'},
        -keyword        => $row->{'keyword'},
        -title          => $row->{'title'},
        -content        => $row->{'content'},
        -category_id    => $row->{'category_id'},
        -category_name  => $row->{'category_name'},
        -priority       => $row->{'priority'},
    );
    return $article;
}

=head2 fetch_article_by_keyword

  Arg[1]      : Int $id - article ID
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                my $article = $helpdb->fetch_article_by_keyword('geneview');
                print $article->title . "\n";
  Description : Fetches an article by keyword from the database
  Return type : EnsEMBL::Web::HelpView::Articles
  Exceptions  : none
  Caller      : general

=cut

sub fetch_article_by_keyword {
    my ($self, $keyword) = @_;
    throw("You must provide a keyword") unless $keyword;

    my $sql = qq(
        SELECT
                a.article_id    as article_id,
                a.keyword       as keyword,
                a.title         as title,
                a.content       as content,
                a.category_id   as category_id,
                c.name          as category_name,
                c.priority      as priority
        FROM
                article a,
                category c
        WHERE   a.keyword = '$keyword'
        AND     a.category_id = c.category_id
    );
    my $sth = $self->dbh->prepare($sql);
    $sth->execute;
    my $row = $sth->fetchrow_hashref;
    my $article = EnsEMBL::Web::HelpView::Article->new(
        -article_id     => $row->{'article_id'},
        -keyword        => $row->{'keyword'},
        -title          => $row->{'title'},
        -content        => $row->{'content'},
        -category_id    => $row->{'category_id'},
        -category_name  => $row->{'category_name'},
        -priority       => $row->{'priority'},
    );
    return $article;
}

=head2 update_article

  Arg[1]      : Int $id - article ID
  Arg[2]      : String $keyword - article keyword
  Arg[3]      : String $title - article title
  Arg[4]      : String $content - article content
  Arg[5]      : Int $category_id - article's category ID
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                $helpdb->update_article(1, 'geneview', 'Geneview',
                  'This is the content', 4);
  Description : updates an article in the database
  Return type : number of rows updated (i.e. 1 on success)
  Exceptions  : none
  Caller      : general

=cut

sub update_article {
    my $self = shift;
    my ($id, $keyword, $title, $content, $category_id) =
        map { $self->dbh->quote($_) } @_;
    my $sql = qq(
        UPDATE  article
        SET
                keyword     = $keyword,
                title       = $title,
                content     = $content,
                category_id = $category_id
        WHERE   article_id = $id
    );
    my $rows = $self->dbh->do($sql);
}

=head2 add_article

  Arg[1]      : String $keyword - article keyword
  Arg[2]      : String $title - article title
  Arg[3]      : String $content - article content
  Arg[4]      : Int $category_id - article's category ID
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                $helpdb->add_article('geneview', 'Geneview',
                  'This is the content', 4);
  Description : adds an article to the database
  Return type : number of rows updated (i.e. 1 on success)
  Exceptions  : none
  Caller      : general

=cut

sub add_article {
    my $self = shift;
    my ($keyword, $title, $content, $category_id) =
        map { $self->dbh->quote($_) } @_;
    my $sql = qq{
        INSERT INTO article (keyword, title, content, category_id)
        VALUES ($keyword, $title, $content, $category_id)
    };
    my $rows = $self->dbh->do($sql);
}

=head2 delete_article

  Arg[1]      : Int $id - article ID
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                $helpdb->delete_article(222);
  Description : deletes an article from the database
  Return type : number of rows updated (i.e. 1 on success)
  Exceptions  : none
  Caller      : general

=cut

sub delete_article {
    my ($self, $id) = @_;
    throw('You must provide an article ID') unless $id;

    my $sql = qq(DELETE FROM article WHERE article_id = $id);
    my $rows = $self->dbh->do($sql);
}

=head2 fetch_all_categories

  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                my $categories = $helpdb->fetch_all_categories;
                foreach my $category (@{ $categories }) {
                    print $category->name . "\n";
                }
  Description : Fetches all help categories from the database
  Return type : listref of EnsEMBL::Web::HelpView::Categories
  Exceptions  : none
  Caller      : general

=cut

sub fetch_all_categories {
    my $self = shift;
    my $sql = qq(
        SELECT
                c.category_id   as category_id,
                c.name          as name,
                c.priority      as priority
        FROM
                category c
        ORDER BY priority
    );
    my $sth = $self->dbh->prepare($sql);
    $sth->execute;
    my @categories;
    while (my $row = $sth->fetchrow_hashref) {
        my $category = EnsEMBL::Web::HelpView::Category->new(
            -category_id    => $row->{'category_id'},
            -name           => $row->{'name'},
            -priority       => $row->{'priority'},
        );
        push @categories, $category;
    }
    return \@categories;
}

=head2 fetch_category_by_id

  Arg[1]      : Int $id - category ID
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                my $category = $helpdb->fetch_category_by_id(2);
                print $category->name . "\n";
  Description : Fetches a category by ID from the database
  Return type : EnsEMBL::Web::HelpView::Categories
  Exceptions  : none
  Caller      : general

=cut

sub fetch_category_by_id {
    my ($self, $id) = @_;
    throw("You must provide a category ID") unless $id;

    my $sql = qq(
        SELECT
                c.category_id   as category_id,
                c.name          as name,
                c.priority      as priority
        FROM
                category c
        WHERE   c.category_id = $id
    );
    my $sth = $self->dbh->prepare($sql);
    $sth->execute;
    my $row = $sth->fetchrow_hashref;
    my $category = EnsEMBL::Web::HelpView::Category->new(
        -category_id    => $row->{'category_id'},
        -name           => $row->{'name'},
        -priority       => $row->{'priority'},
    );
    return $category;
}

=head2 update_category

  Arg[1]      : Int $id - category ID
  Arg[2]      : String $name - category name
  Arg[3]      : Int $priority - category priority
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                $helpdb->update_category(1, 'General', 1);
  Description : updates a category in the database
  Return type : number of rows updated (i.e. 1 on success)
  Exceptions  : none
  Caller      : general

=cut

sub update_category {
    my $self = shift;
    my ($id, $name, $priority) = map { $self->dbh->quote($_) } @_;
    my $sql = qq(
        UPDATE  category
        SET
                name = $name,
                priority = $priority
        WHERE   category_id = $id
    );
    my $rows = $self->dbh->do($sql);
}

=head2 add_category

  Arg[1]      : String $name - category name
  Arg[2]      : Int $priority - category priority
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                $helpdb->add_category('Other', 7);
  Description : adds a category to the database
  Return type : number of rows updated (i.e. 1 on success)
  Exceptions  : none
  Caller      : general

=cut

sub add_category {
    my $self = shift;
    my ($name, $priority) = map { $self->dbh->quote($_) } @_;
    my $sql = qq{
        INSERT INTO category (name, priority)
        VALUES ($name, $priority)
    };
    my $rows = $self->dbh->do($sql);
}

=head2 delete_category

  Arg[1]      : Int $id - category ID
  Example     : my $helpdb = EnsEMBL::Web::HelpView::HelpAdaptor->new();
                $helpdb->delete_category(2);
  Description : deletes a category from the database
  Return type : number of rows updated (i.e. 1 on success)
  Exceptions  : none
  Caller      : general

=cut

sub delete_category {
    my ($self, $id) = @_;
    throw('You must provide a category ID') unless $id;

    my $sql = qq(DELETE FROM category WHERE category_id = $id);
    my $rows = $self->dbh->do($sql);
}

1;

