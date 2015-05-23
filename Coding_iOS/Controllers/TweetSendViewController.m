//
//  TweetSendViewController.m
//  Coding_iOS
//
//  Created by 王 原闯 on 14-9-1.
//  Copyright (c) 2014年 Coding. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import "TweetSendViewController.h"
#import "TweetSendTextCell.h"
#import "TweetSendImagesCell.h"
#import "Coding_NetAPIManager.h"
#import "UsersViewController.h"
#import "Helper.h"
#import "TweetSendLocationViewController.h"
#import "TweetSendLocation.h"
#import <TPKeyboardAvoiding/TPKeyboardAvoidingTableView.h>

@interface TweetSendViewController ()<UITableViewDataSource, UITableViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, QBImagePickerControllerDelegate, UIScrollViewDelegate>
@property (strong, nonatomic) UITableView *myTableView;
@property (strong, nonatomic) Tweet *curTweet;;
@end

@implementation TweetSendViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _curTweet = [Tweet tweetForSend];
    _locationData = _curTweet.locationData;

    [self.navigationItem setLeftBarButtonItem:[UIBarButtonItem itemWithBtnTitle:@"取消" target:self action:@selector(cancelBtnClicked:)] animated:YES];
    
    UIBarButtonItem *buttonItem = [UIBarButtonItem itemWithBtnTitle:@"发送" target:self action:@selector(sendTweet)];
    [self.navigationItem setRightBarButtonItem:buttonItem animated:YES];
    @weakify(self);
    RAC(self.navigationItem.rightBarButtonItem, enabled) =
    [RACSignal combineLatest:@[RACObserve(self, curTweet.tweetContent),
                               RACObserve(self, curTweet.tweetImages)] reduce:^id (NSString *mdStr){
                                   @strongify(self);
                                   return @(![self isEmptyTweet]);
                               }];
    self.title = [NSString stringWithFormat:@"发冒泡"];
    
    //    添加myTableView
    _myTableView = ({
        TPKeyboardAvoidingTableView *tableView = [[TPKeyboardAvoidingTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        tableView.backgroundColor = [UIColor clearColor];
        tableView.dataSource = self;
        tableView.delegate = self;
        tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        [tableView registerClass:[TweetSendTextCell class] forCellReuseIdentifier:kCellIdentifier_TweetSendText];
        [tableView registerClass:[TweetSendImagesCell class] forCellReuseIdentifier:kCellIdentifier_TweetSendImages];
        [self.view addSubview:tableView];
        [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.view);
        }];
        tableView;
    });
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (BOOL)becomeFirstResponder{
    [super becomeFirstResponder];
    TweetSendTextCell *cell = (TweetSendTextCell *)[self.myTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if ([cell respondsToSelector:@selector(becomeFirstResponder)]) {
        [cell becomeFirstResponder];
    }
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setLocationData:(TweetSendLocationResponse *)locationData
{
    _locationData = locationData;
    _curTweet.locationData = locationData;
    [self.myTableView reloadData];
}

#pragma mark Table M

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 2;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    __weak typeof(self) weakSelf = self;
    if (indexPath.row == 0) {
        TweetSendTextCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier_TweetSendText forIndexPath:indexPath];
        cell.tweetContentView.text = _curTweet.tweetContent;
        [cell setLocationStr:self.locationData.displayLocaiton];
        cell.textValueChangedBlock = ^(NSString *valueStr){
            weakSelf.curTweet.tweetContent = valueStr;
        };
        cell.photoBtnBlock = ^(){
            [weakSelf showActionForPhoto];
        };
        cell.locationBtnBlock = ^(){
            TweetSendLocationViewController *vc = [[TweetSendLocationViewController alloc] init];
            vc.responseData = self.locationData;
            UINavigationController *nav = [[BaseNavigationController alloc] initWithRootViewController:vc];
            [weakSelf presentViewController:nav animated:YES completion:nil];
        };
        return cell;
    }else {
        TweetSendImagesCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier_TweetSendImages forIndexPath:indexPath];
        cell.curTweet = _curTweet;
        cell.addPicturesBlock = ^(){
            [self showActionForPhoto];
        };
        cell.deleteTweetImageBlock = ^(TweetImage *toDelete){
            [weakSelf.curTweet deleteATweetImage:toDelete];
            [weakSelf.myTableView reloadData];
        };
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    CGFloat cellHeight = 0;
    if (indexPath.row == 0) {
        cellHeight = [TweetSendTextCell cellHeight];
    }else if(indexPath.row == 1){
        cellHeight = [TweetSendImagesCell cellHeightWithObj:_curTweet];
    }
    return cellHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark UIActionSheet M

- (void)showActionForPhoto{
    if (_curTweet.tweetImages.count >= 6) {
        kTipAlert(@"最多只可选择6张照片");
        return;
    }
    @weakify(self);
    [[UIActionSheet bk_actionSheetCustomWithTitle:nil buttonTitles:@[@"拍照", @"从相册选择"] destructiveTitle:nil cancelTitle:@"取消" andDidDismissBlock:^(UIActionSheet *sheet, NSInteger index) {
        @strongify(self);
        [self photoActionSheet:sheet DismissWithButtonIndex:index];
    }] showInView:self.view];
}

- (void)photoActionSheet:(UIActionSheet *)sheet DismissWithButtonIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 0) {
        //        拍照
        if (![Helper checkCameraAuthorizationStatus]) {
            return;
        }
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.allowsEditing = NO;//设置可编辑
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:picker animated:YES completion:nil];//进入照相界面
    }else if (buttonIndex == 1){
        //        相册
        if (![Helper checkPhotoLibraryAuthorizationStatus]) {
            return;
        }
        QBImagePickerController *imagePickerController = [[QBImagePickerController alloc] init];
        [imagePickerController.selectedAssetURLs removeAllObjects];
        [imagePickerController.selectedAssetURLs addObjectsFromArray:self.curTweet.selectedAssetURLs];
        imagePickerController.filterType = QBImagePickerControllerFilterTypePhotos;
        imagePickerController.delegate = self;
        imagePickerController.allowsMultipleSelection = YES;
        imagePickerController.maximumNumberOfSelection = 6;
        UINavigationController *navigationController = [[BaseNavigationController alloc] initWithRootViewController:imagePickerController];
        [self presentViewController:navigationController animated:YES completion:NULL];
    }
}

#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    UIImage *pickerImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    [assetsLibrary writeImageToSavedPhotosAlbum:[pickerImage CGImage] orientation:(ALAssetOrientation)pickerImage.imageOrientation completionBlock:^(NSURL *assetURL, NSError *error) {
        [self.curTweet addASelectedAssetURL:assetURL];
        [self.myTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
    }];
    [picker dismissViewControllerAnimated:YES completion:^{}];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark QBImagePickerControllerDelegate
- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAssets:(NSArray *)assets{
    NSMutableArray *selectedAssetURLs = [NSMutableArray new];
    [imagePickerController.selectedAssetURLs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [selectedAssetURLs addObject:obj];
    }];
    @weakify(self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.curTweet.selectedAssetURLs = selectedAssetURLs;
        dispatch_async(dispatch_get_main_queue(), ^{
            @strongify(self);
            [self.myTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
        });
    });
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Nav Btn M
- (void)cancelBtnClicked:(id)sender{
    if ([self isEmptyTweet] && !_curTweet.locationData) {//有位置
        [Tweet deleteSendData];
        [self dismissSelf];
    }else{
        __weak typeof(self) weakSelf = self;
        [[UIActionSheet bk_actionSheetCustomWithTitle:@"是否保存草稿" buttonTitles:@[@"保存"] destructiveTitle:@"不保存" cancelTitle:@"取消" andDidDismissBlock:^(UIActionSheet *sheet, NSInteger index) {
            if (index == 0) {
                [weakSelf.curTweet saveSendData];
            }else if (index == 1){
                [Tweet deleteSendData];
            }else{
                return ;
            }
            [weakSelf dismissSelf];
        }] showInView:self.view];
    }
}

- (void)dismissSelf{
    [self.view endEditing:YES];
    TweetSendTextCell *cell = (TweetSendTextCell *)[self.myTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if (cell.footerToolBar) {
        [cell.footerToolBar removeFromSuperview];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)isEmptyTweet{
    BOOL isEmptyTweet = YES;
    if ((_curTweet.tweetContent && ![_curTweet.tweetContent isEmpty])//内容不为空
        || _curTweet.tweetImages.count > 0)//有照片
    {
        isEmptyTweet = NO;
    }
    return isEmptyTweet;
}

- (void)sendTweet{
    _curTweet.tweetContent = [_curTweet.tweetContent aliasedString];
    if (_sendNextTweet) {
        _sendNextTweet(_curTweet);
    }
    [self dismissSelf];
}

- (void)enableNavItem:(BOOL)isEnable{
    self.navigationItem.leftBarButtonItem.enabled = isEnable;
    self.navigationItem.rightBarButtonItem.enabled = isEnable;
}

- (void)dealloc
{
    _myTableView.delegate = nil;
    _myTableView.dataSource = nil;
}

#pragma mark 
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    if (scrollView == self.myTableView) {
        [self.view endEditing:YES];
    }
}

@end
