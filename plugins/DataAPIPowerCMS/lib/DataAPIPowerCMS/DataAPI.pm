package DataAPIPowerCMS::DataAPI;

use strict;
use warnings;

use MT::DataAPI::Endpoint::Common;
use MT::DataAPI::Resource;

use CustomFields::Util qw( get_meta );
use lib qw( addons/PowerCMS.pack/lib );
use PowerCMS::Util qw( is_user_can current_ts valid_ts upload site_path file_basename file_extension );

sub _data_api_endpoint_get_customobject {
    my ( $app, $endpoint ) = @_;
    my ( $blog, $customobject ) = context_objects( @_ ) or return;
    my $class = $customobject->class;
    run_permission_filter( $app, 'data_api_view_permission_filter', $class ) or return;
    my $user = $app->user;
    if ( $user ) {
        if (! __permission( $user, $blog, $class ) ) {
            $user = undef;
        }
    }
    if ( (! $user ) && ( $customobject->status != 2 ) ) {
        return;
    }
    return $customobject;
}

sub _data_api_endpoint_get_campaign {
    my ( $app, $endpoint ) = @_;
    my ( $blog, $banner ) = context_objects( @_ ) or return;
    my $class = 'campaign';
    run_permission_filter( $app, 'data_api_view_permission_filter', $class ) or return;
    my $user = $app->user;
    if ( $user ) {
        if (! __permission( $user, $blog, $class ) ) {
            $user = undef;
        }
    }
    if ( (! $user ) && ( $banner->status != 2 ) ) {
        return;
    }
    return $banner;
}

sub _data_api_endpoint_customobjects {
    my ( $app, $endpoint ) = @_;
    my ( $blog ) = context_objects( @_ ) or return;
    my $class = $app->param( 'class' ) || 'customobject';
    run_permission_filter( $app, 'data_api_list_permission_filter', $class ) or return;
    my $args;
    my $sort_order = 'descend';
    my $sort_by = 'id';
    my $user = $app->user;
    if ( $user ) {
        if (! __permission( $user, $blog, $class ) ) {
            $user = undef;
        }
    }
    my @sort_col = qw( authored_on modified_on period_on id keywords name );
    if ( my $sortBy = $app->param( 'sortBy' ) ) {
        if ( grep( /^$sortBy$/, @sort_col ) ) {
            $sort_by = $sortBy;
        }
    }
    if ( my $sortOrder = $app->param( 'sortOrder' ) ) {
        if ( $sortOrder eq 'ascend' ) {
            $sort_order = $sortOrder;
        }
    }
    $args->{ sort_by } = $sort_by;
    $args->{ direction } = $sort_order;
    my $limit = 10;
    if ( $app->param( 'limit' ) ) {
        $limit = $app->param( 'limit' ) + 0;
    }
    my $offset = 0;
    if ( $app->param( 'offset' ) ) {
        $offset = $app->param( 'offset' ) + 0;
    }
    $args->{ limit } = $limit;
    $args->{ offset } = $offset;
    my $terms = { blog_id => $blog->id };
    if (! $user ) {
        $terms->{ status } = 2;
    } else {
        if ( my $status = $app->param( 'status' ) ) {
            my $status_int = MT->model( $class )->status_int( $status );
            $terms->{ status } = $status_int;
        }
    }
    $terms->{ class } = $class;
    if ( my $search = $app->param( 'search' ) ) {
        $search = MT::Util::trim( $search );
        my $searchFields = $app->param( 'searchFields' ) || 'name,body,keywords';
        my @fields = split( /,/, $searchFields );
        for my $field( @fields ) {
            $field = MT::Util::trim( $field );
            $terms->{ $field } = { like => '%' . $search . '%' };
        }
    }
    if ( my $folder = $app->param( 'folder' ) ) {
        if ( my @folders = __folder_path_to_obj( $blog, $folder ) ) {
             $terms->{ category_id } = $folders[ 0 ]->id;
        }
    }
    my $group = $app->param( 'group' );
    my $group_id = $app->param( 'group_id' );
    if ( $group || $group_id ) {
        require CustomObject::CustomObjectGroup;
        require CustomObject::CustomObjectOrder;
        if (! $group_id ) {
            my $cg = CustomObject::CustomObjectGroup->load( { name => $group, blog_id => $blog->id } )
                or return _none_match();
            $group_id = $cg->id;
        }
        $args->{ 'join' } = [ 'CustomObject::CustomObjectOrder', 'customobject_id',
                   { group_id => $group_id, },
                   { 'sort' => 'order',
                     direction => 'ascend',
                   } ];
    }
    my $count = MT->model( $class )->count( $terms );
    my @custom_objects = MT->model( $class )->load( $terms, $args );
    return {
        totalResults => $count + 0,
        items => \@custom_objects,
    };
    return [];
}

sub _data_api_endpoint_campaigns {
    my ( $app, $endpoint ) = @_;
    my ( $blog ) = context_objects( @_ ) or return;
    my $class = 'campaign';
    run_permission_filter( $app, 'data_api_list_permission_filter', $class ) or return;
    my $args;
    my $sort_order = 'descend';
    my $sort_by = 'id';
    my $user = $app->user;
    if ( $user ) {
        if (! __permission( $user, $blog, $class ) ) {
            $user = undef;
        }
    }
    my @sort_col = qw( created_on modified_on publishing_on period_on id title );
    if ( my $sortBy = $app->param( 'sortBy' ) ) {
        if ( grep( /^$sortBy$/, @sort_col ) ) {
            $sort_by = $sortBy;
        }
    }
    if ( my $sortOrder = $app->param( 'sortOrder' ) ) {
        if ( $sortOrder eq 'ascend' ) {
            $sort_order = $sortOrder;
        }
    }
    $args->{ sort_by } = $sort_by;
    $args->{ direction } = $sort_order;
    my $limit = 10;
    if ( $app->param( 'limit' ) ) {
        $limit = $app->param( 'limit' ) + 0;
    }
    my $offset = 0;
    if ( $app->param( 'offset' ) ) {
        $offset = $app->param( 'offset' ) + 0;
    }
    $args->{ limit } = $limit;
    $args->{ offset } = $offset;
    my $terms = { blog_id => $blog->id };
    if (! $user ) {
        $terms->{ status } = 2;
    } else {
        if ( my $status = $app->param( 'status' ) ) {
            my $status_int = __status_int( $status );
            return $status_int;
            $terms->{ status } = $status_int;
        }
    }
    if ( my $search = $app->param( 'search' ) ) {
        $search = MT::Util::trim( $search );
        my $searchFields = $app->param( 'searchFields' ) || 'title,text,memo';
        my @fields = split( /,/, $searchFields );
        for my $field( @fields ) {
            $field = MT::Util::trim( $field );
            $terms->{ $field } = { like => '%' . $search . '%' };
        }
    }
    my $active = $app->param( 'active' );
    if ( $active ) {
        my $ts = current_ts( $blog );
        $terms->{ publishing_on } = { '<' => $ts };
        $terms->{ period_on }     = { '>' => $ts };
        $terms->{ status } = 2;
    }
    my $group = $app->param( 'group' );
    my $group_id = $app->param( 'group_id' );
    if ( $group || $group_id ) {
        require Campaign::CampaignGroup;
        require Campaign::CampaignOrder;
        if (! $group_id ) {
            my $cg = Campaign::CampaignGroup->load( { name => $group, blog_id => $blog->id } )
                or return _none_match();
            $group_id = $cg->id;
        }
        $args->{ 'join' } = [ 'Campaign::CampaignOrder', 'campaign_id',
                   { group_id => $group_id, },
                   { 'sort' => 'order',
                     direction => 'ascend',
                   } ];
    }
    my $count = MT->model( $class )->count( $terms );
    my @banners = MT->model( $class )->load( $terms, $args );
    return {
        totalResults => $count + 0,
        items => \@banners,
    };
}

sub _data_api_endpoint_create_customobject {
    my ( $app, $endpoint ) = @_;
    my ( $blog, $customobject ) = context_objects( @_ ) or return;
    my $class = $app->param( 'class' ) || 'customobject';
    my $author = $app->user;
    if (! __permission( $author, $blog, $class ) ) {
        return;
    }
    my $orig_customobject = $customobject;
    if (! $orig_customobject ) {
        $orig_customobject = $app->model( $class )->new;
        $orig_customobject->set_values(
            {   blog_id   => $blog->id,
                author_id => $author->id,
            }
        );
    }
    if ( $orig_customobject && ( $orig_customobject->class ne $class ) ) {
        return;
    }
    $orig_customobject->class( $class );
    my $plugin_customobject = MT->component( $class );
    my $cfg_plugin;
    if ( $class eq 'customobject' ) {
        $cfg_plugin = MT->component( 'CustomObjectConfig' );
    } else {
        $cfg_plugin = $plugin_customobject;
    }
    my $new_customobject = $app->resource_object( 'customobject', $orig_customobject )
        or return;
    $new_customobject->class( $class );
    if (! $new_customobject->status ) {
        my $default_status = $cfg_plugin->get_config_value( 'default_status', 'blog:'. $blog->id );
        $orig_customobject->status( $default_status );
        $new_customobject->status( $default_status );
    }
    save_object( $app, $class, $new_customobject, $orig_customobject, ) or return;
    $orig_customobject->clear_cache();
    require CustomObject::Plugin;
    CustomObject::Plugin::_cms_post_save_customobject( undef, $app, $new_customobject, $orig_customobject );
    my $message;
    if (! $customobject ) {
        $message = $plugin_customobject->translate( "[_1] '[_2]' (ID:[_3]) created by '[_4]'", $new_customobject->class_label, $new_customobject->name, $new_customobject->id, $author->name );
    } else {
        $message = $plugin_customobject->translate( "[_1] '[_2]' (ID:[_3]) edited by '[_4]'", $new_customobject->class_label, $new_customobject->name, $new_customobject->id, $author->name );
    }
    $app->log( {
        message => $message,
        blog_id => $orig_customobject->blog_id,
        author_id => $author->id,
        class => $class,
        level => MT::Log::INFO(),
    } );
    return $new_customobject;
}

sub _data_api_endpoint_delete_customobject {
    my ( $app, $endpoint ) = @_;
    my ( $blog, $customobject ) = context_objects( @_ ) or return;
    my $class = $app->param( 'class' ) || 'customobject';
    run_permission_filter( $app, 'data_api_delete_permission_filter', $class ) or return;
    my $author = $app->user;
    if (! __permission( $author, $blog, $class ) ) {
        return;
    }
    $customobject->remove or die $customobject->errstr;
    require CustomObject::Plugin;
    CustomObject::Plugin::_cms_post_delete_customobject( undef, $app, $customobject, $customobject );
    my $plugin_customobject = MT->component( $class );
    my $message = $plugin_customobject->translate( "[_1] '[_2]' (ID:[_3]) deleted by '[_4]'",
        $customobject->class_label, $customobject->name, $customobject->id, $author->name );
    $app->log( {
        message => $message,
        blog_id => $customobject->blog_id,
        author_id => $author->id,
        class => $class,
        level => MT::Log::INFO(),
    } );
    return $customobject;
}

sub _data_api_endpoint_create_campaign {
    my ( $app, $endpoint ) = @_;
    my ( $blog, $banner ) = context_objects( @_ ) or return;
    my $class = 'campaign';
    require Campaign::Plugin;
    require Campaign::Campaign;
    if (! Campaign::Plugin::_campaign_permission( $blog ) ) {
        return;
    }
    my $author = $app->user;
    my $orig_campaign = $banner;
    if (! $orig_campaign ) {
        $orig_campaign = $app->model( $class )->new;
        $orig_campaign->set_values(
            {   blog_id   => $blog->id,
                author_id => $author->id,
            }
        );
    }
    my $new_campaign = $app->resource_object( 'campaign', $orig_campaign )
        or return;
    my $site_path = site_path( $blog );
    my $plugin_campaign = MT->component( 'Campaign' );
    my $banner_directory = $plugin_campaign->get_config_value( 'banner_directory', 'blog:'. $blog->id );
    if (! $new_campaign->status ) {
        my $default_status = $plugin_campaign->get_config_value( 'default_status', 'blog:'. $blog->id );
        $orig_campaign->status( $default_status );
        $new_campaign->status( $default_status );
    }
    my $upload_dir = File::Spec->catdir( $site_path, $banner_directory );
    require MT::Asset;
    if ( $app->param( 'image' ) ) {
        my $rename;
        my $file_name = file_basename( $app->param->upload( 'image' ) );
        my $asset_pkg = MT::Asset->handler_for_file( $file_name );
        if ( $asset_pkg eq 'MT::Asset::Image' ) {
            my %params = ( author  => $author,
                           label   => $orig_campaign->title,
                           rename  => 1,
                           singler => 1,
                          );
            my $image = upload( $app, $blog, 'image', $upload_dir, \%params );
            my $original;
            if ( my $id = $orig_campaign->image_id ) {
                $original = $asset_pkg->load( $id );
            }
            if ( defined $image ) {
                $orig_campaign->image_id( $image->id );
                if ( $original ) {
                    if ( $original->id != $image->id ) {
                        $original->remove or die $original->errstr;
                    }
                }
            }
        }
    }
    if ( $app->param( 'movie' ) ) {
        my $rename;
        my $file_name = file_basename( $app->param->upload( 'movie' ) );
        my $asset_pkg = MT::Asset->handler_for_file( $file_name );
        if ( ( $asset_pkg eq 'MT::Asset::Video' )
          || ( file_extension( $file_name ) eq 'swf' ) ) {
            my %params = ( author  => $author,
                           label   => $orig_campaign->title,
                           rename  => 1,
                           singler => 1,
                          );
            my $movie = upload( $app, $blog, 'movie', $upload_dir, \%params );
            if ( defined $movie ) {
                $orig_campaign->movie_id( $movie->id );
            }
        }
    }
    if (! $orig_campaign->basename ) {
        $orig_campaign->basename( Campaign::Campaign::make_unique_basename( $orig_campaign ) );
        $new_campaign->basename( Campaign::Campaign::make_unique_basename( $new_campaign ) );
    }
    save_object( $app, 'campaign', $new_campaign, $orig_campaign, ) or return;
    $orig_campaign->clear_cache();
    my $message;
    if (! $banner ) {
        $message = $plugin_campaign->translate( 'Campaign \'[_1]\' (ID:[_2]) created by \'[_3]\'', $new_campaign->title, $new_campaign->id, $author->name );
    } else {
        $message = $plugin_campaign->translate( 'Campaign \'[_1]\' (ID:[_2]) edited by \'[_3]\'', $new_campaign->title, $new_campaign->id, $author->name );
    }
    $app->log( {
        message => $message,
        blog_id => $orig_campaign->blog_id,
        author_id => $author->id,
        class => 'campaign',
        level => MT::Log::INFO(),
    } );
    return $new_campaign;
}

sub _data_api_endpoint_delete_campaign {
    my ( $app, $endpoint ) = @_;
    my ( $blog, $banner ) = context_objects( @_ ) or return;
    my $class = 'campaign';
    require Campaign::Plugin;
    run_permission_filter( $app, 'data_api_delete_permission_filter', $class ) or return;
    if (! Campaign::Plugin::_campaign_permission( $blog ) ) {
        return;
    }
    $banner->remove or die $banner->errstr;
    my $author = $app->user;
    my $plugin_campaign = MT->component( 'Campaign' );
    my $message = $plugin_campaign->translate( 'Campaign \'[_1]\' (ID:[_2]) deleted by \'[_3]\'',
        $banner->title, $banner->id, $author->name );
    $app->log( {
        message => $message,
        blog_id => $banner->blog_id,
        author_id => $author->id,
        class => 'campaign',
        level => MT::Log::INFO(),
    } );
    return $banner;
}

sub to_tags {
    my ( $hash, $obj ) = @_;
    if ( ref $hash->{ tags } eq 'ARRAY' ) {
        $obj->set_tags( @{ $hash->{tags} }, { force => 1 } );
    }
    return;
}

sub _none_match {
    return {
        totalResults => 0,
        items => [],
    };
}

sub permalink {
    my ( $obj, $hash, $field, $stash ) = @_;
    return $obj->permalink;
}

sub folder {
    my ( $obj, $hash, $field, $stash ) = @_;
    my $folder_path = $obj->folder_path;
    my $path2folder;
    if ( $folder_path ) {
        my @pathes;
        for my $f ( @$folder_path ) {
            push ( @pathes, $f->basename );
        }
        $path2folder = join( '/', @pathes );
        $path2folder = '/' . $path2folder . '/';
    } else {
        $path2folder = '/';
    }
    return $path2folder;
}

sub get_banner {
    my ( $obj, $hash, $field, $stash ) = @_;
    if ( my $image = $obj->image ) {
        return $image->url;
    }
    return '';
}

sub get_movie {
    my ( $obj, $hash, $field, $stash ) = @_;
    if ( my $movie = $obj->movie ) {
        return $movie->url;
    }
    return '';
}

sub customFields {
    my ( $obj, $hash, $field, $stash ) = @_;
    require CustomFields::DataAPI;
    my $meta = get_meta( $obj );
    [   map {
            +{  basename => $_->basename,
                value    => $meta->{ $_->basename },
            };
        } @{ CustomFields::DataAPI::custom_fields( $obj ) }
    ];
}

sub to_customFields {
    my ( $hash, $obj ) = @_;
    require CustomFields::DataAPI;
    my %values = ();
    for my $v ( @{ $hash->{ customFields } || [] } ) {
        $values{ $v->{ basename } } = $v->{ value };
    }
    for my $f ( @{ CustomFields::DataAPI::custom_fields( $obj ) } ) {
        my $bn = $f->basename;
        $obj->meta( 'field.' . $bn, $values{ $bn } )
            if exists $values{ $bn };
    }
    return;
}

sub tags {
    my ( $obj, $hash, $field, $stash ) = @_;
    return [ $obj->tags ];
}

sub image_width {
    my ( $obj, $hash, $field, $stash ) = @_;
    my $asset = $obj->image or return 0;
    if ( $asset->class eq 'image' ) {
        return $asset->image_width;
    }
    return 0;
}

sub image_height {
    my ( $obj, $hash, $field, $stash ) = @_;
    my $asset = $obj->image or return 0;
    if ( $asset->class eq 'image' ) {
        return $asset->image_height;
    }
    return 0;
}

sub status_text {
    my ( $obj, $hash, $field, $stash ) = @_;
    return $obj->status_text;
}

sub __folder_path_to_obj {
    my ( $blog, $path ) = @_;
    my $class = MT->model( 'folder' );
    my @cat_path = $path =~ m@(\[[^]]+?\]|[^]/]+)@g;
    @cat_path = map { $_ =~ s/^\[(.*)\]$/$1/; $_ } @cat_path;
    my $last_cat_id = 0;
    my $cat;
    my $top  = shift @cat_path;
    my @cats = $class->load(
        {   basename  => $top,
            parent => 0,
            blog_id => $blog->id,
        }
    );
    if ( @cats ) {
        for my $label ( @cat_path ) {
            my @parents = map { $_->id } @cats;
            @cats = $class->load(
                {   basename  => $label,
                    parent => \@parents,
                    blog_id => $blog->id,
                },
            ) or last;
        }
    }
    if ( !@cats && $path ) {
        @cats = (
            $class->load(
                {   basename => $path,
                    blog_id => $blog->id,
                },
            )
        );
    }
    @cats;
}

sub to_status {
    my ( $hash, $obj ) = @_;
    if ( my $status = $hash->{ status } ) {
        $status = __status_int( $status );
        $hash->{ status } = $status;
        $obj->status( $status );
    }
    return;
}

sub to_co_status {
    my ( $hash, $obj ) = @_;
    if ( my $status = $hash->{ status } ) {
        $status = $obj->status_int( $status );
        $hash->{ status } = $status;
        $obj->status( $status );
    }
    return;
}

sub __status_int {
    my $status = shift;
    $status = uc( $status );
    return 1 if $status eq 'DRAFT' || $status eq 'HOLD';
    return 2 if $status eq 'PUBLISHED' || $status eq 'PUBLISHING' || $status eq 'RELEASE';
    return 3 if $status eq 'RESERVED' || $status eq 'FUTURE';
    return 4 if $status eq 'FINISED' || $status eq 'CLOSED' || $status eq 'ENDED';
    return 0;
}

sub __permission {
    my ( $user, $blog, $class ) = @_;
    return 1 if $user->is_superuser;
    if ( is_user_can( $blog, $user, 'administer_blog' ) ) {
        return 1;
    }
    if ( is_user_can( $blog, $user, 'administer_website' ) ) {
        return 1;
    }
    if ( is_user_can( $blog, $user, 'manage_' . $class ) ) {
        return 1;
    }
    return 0;
}

1;