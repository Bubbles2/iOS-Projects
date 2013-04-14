/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

#import "GameOfLifeLayer.h"
#import "OptionsLayer.h"
#import "PoolOfLife.h"
#import "SoundManager.h"

@interface GameOfLifeLayer () <PoolOfLifeDelegate, OptionsLayerDelegate>
@property (nonatomic) BOOL done;
@property (nonatomic, strong) PoolOfLife *game;
//Define next grid update. Maybe a from an rng.
@property (nonatomic) ccTime nextUpdateTime;
@property (nonatomic) ccTime currentTime;
@property (nonatomic) ccColor4F toggleButtonColor;
@property (nonatomic) ccColor4F resetButtonColor;
@property (nonatomic, weak) CCLabelTTF *toggleLabel;
@property (nonatomic, strong) SoundManager *soundManager;
@property (nonatomic, strong) OptionsLayer *optionsLayer;
@property (nonatomic, weak) KKRotationRate *rotationRate;
@property (nonatomic) float currentIntensity;
//Window properties
@property (nonatomic) NSInteger widthWindow;
@property (nonatomic) NSInteger heightWindow;
@property (nonatomic) CGFloat yOffset;
@property (nonatomic) CGFloat cellWidthPercentage;
@property (nonatomic) NSInteger cellWidth;
@property (nonatomic) NSInteger widthGame;
@property (nonatomic) NSInteger heightGame;
@property (nonatomic) NSInteger gameOffset;
@property (nonatomic) NSInteger numRows;
@property (nonatomic) NSInteger numCols;
@property (nonatomic) float delayInSeconds;
@property (nonatomic) CGFloat fontSize;
//Game properties
@property (nonatomic) kPoolOfLifeGameMode gameMode;
@end

@implementation GameOfLifeLayer

#define TOGGLE_BUTTON_COLOR_NORMAL ccc4f(150.0/255.0, 0.0, 1.0, 1.0)
#define BUTTON_COLOR_PRESSED ccc4f(1.0, 0.0, 1.0, 1.0)
#define RESET_BUTTON_COLOR_NORMAL ccc4f(50.0/255.0, 0.0, 1.0, 1.0)
#define CELL_COLOR ccc4f(100.0/255.0, 0, 1.0, 1.0)
#define FOOD_COLOR ccc4f(188.0/255.0, 143.0/255.0, 143.0/255.0, 1.0) //188-143-143 = "Rosy Brown"

#pragma mark -

-(OptionsLayer *)optionsLayer
{
    if(!_optionsLayer)
    {
        _optionsLayer = [OptionsLayer node];
        _optionsLayer.delegate = self;
    }
    return _optionsLayer;
}

-(void)setDone:(BOOL)done
{
    _done = done;
    if(done)
    {
        self.soundManager.playing = NO;
        self.toggleButtonColor = BUTTON_COLOR_PRESSED;
        self.toggleLabel.string = @"Stopped";
    }
    else
    {
        self.soundManager.playing = YES;
        self.toggleButtonColor = TOGGLE_BUTTON_COLOR_NORMAL;
        self.toggleLabel.string = @"Running";
    }
}

-(PoolOfLife *)game
{
    if(!_game)
    {
        _game = [[PoolOfLife alloc] initWithRows:self.numRows cols:self.numCols gameMode:self.gameMode];
    }
    return _game;
}

#pragma mark Lifecycle

-(id) init
{
	if ((self = [super init]))
	{
        //Properties
        self.heightWindow = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 1024 : 480);
        self.widthWindow = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 768 : 320);
        self.yOffset = (self.heightWindow * .04375f);
        self.cellWidthPercentage = 0.0625f;
        self.cellWidth = (NSInteger)(self.widthWindow * self.cellWidthPercentage);
        self.widthGame = self.widthWindow;
        self.gameOffset = (NSInteger)(self.heightWindow * .125);
        self.heightGame = self.heightWindow - self.gameOffset;
        self.numCols = self.widthGame / self.cellWidth;
        self.numRows = self.heightGame / self.cellWidth;
        self.delayInSeconds = 0.15f;
        self.fontSize = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 26.0f : 18.0f);
        self.gameMode = kPoolOfLifeGameModeConway;
        
        //Natural Major scale
        self.soundManager = [[SoundManager alloc] initWithScale:kSoundManagerScaleIonian];
        self.game.delegate = self;
        
        [self reset:NO];
        //[self schedule:@selector(nextStep) interval:DELAY_IN_SECONDS];
        [self scheduleUpdate];
        CCLabelTTF *resetButton = [CCLabelTTF labelWithString:@"Reset" fontName:@"Helvetica" fontSize:self.fontSize];
        resetButton.position = CGPointMake(self.widthWindow / 4, self.heightWindow - self.yOffset);
        self.toggleLabel = [CCLabelTTF labelWithString:@"Running" fontName:@"Helvetica" fontSize:self.fontSize];
        self.toggleLabel.position = CGPointMake((self.widthWindow / 4) * 3, self.heightWindow - self.yOffset);
        self.toggleButtonColor = TOGGLE_BUTTON_COLOR_NORMAL;
        [self addChild:resetButton];
        [self addChild:self.toggleLabel];
	}
	return self;
}

-(void)reset:(BOOL)withColorChange
{
    [self.game reset];
    if(withColorChange)
    {
        self.resetButtonColor = BUTTON_COLOR_PRESSED;
        [self scheduleOnce:@selector(resetButtonNormal) delay:self.delayInSeconds];
    }
    else
    {
        self.resetButtonColor = RESET_BUTTON_COLOR_NORMAL;
    }
}

-(void)resetButtonNormal
{
    self.resetButtonColor = RESET_BUTTON_COLOR_NORMAL;
}

#pragma mark -

//-(void)didActivateCellAtRow:(NSInteger)row col:(NSInteger)col numActive:(NSInteger)numActive
//{
//    //Float32 pitch = ((440.0f / NUM_COLS) * (col + 1)) / 440.0f; //Based on column
//    Float32 gain = ((row + 1.0f) / (4 * NUM_ROWS)) * (1.0f / numActive); //Based on row
//    //NSLog(@"pitch: %g, gain: %g, active: %d", pitch, gain, self.cellsCurrentlyActive);
//    //[self.audioEngine playEffect:@"a-sound.WAV" pitch:pitch pan:0 gain:gain];
//    [self.audioEngine playEffect:[SOUNDS objectAtIndex:(col % [SOUNDS count])] pitch:1.0f pan:0.0f gain:gain];
//}

-(void)didFinishUpdatingRowWithResultingRow:(NSArray *)row
{
    if(!self.soundManager.isPlaying)
    {
        self.soundManager.playing = YES;
    }
//    float intensity = self.currentIntensity;
//    float intensityStep = 0.15f;
//    if(self.rotationRate)
//    {
//        //NSLog(@"x: %g, y: %g, z: %g", self.rotationRate.x, self.rotationRate.y, self.rotationRate.z);
//        intensity += self.rotationRate.x * intensityStep;
//        NSLog(@"Intensity: %g", intensity);
//        if(intensity < 0.0f)
//        {
//            intensity = 0.0f;
//        }
//        if(intensity > 1.0f)
//        {
//            intensity = 1.0f;
//        }
//        self.currentIntensity = intensity;
//    }
    [self.soundManager pushRow:row intensity:self.currentIntensity];
}

-(void)didFinishWithOptionsLayer
{
    [self.optionsLayer layerWillDisappear];
    [self removeChild:self.optionsLayer];
}

-(void)didSetOption:(kGameOfLifeOption)option withValue:(id)value
{
    switch (option) {
        case kGameOfLifeOptionGameMode:
            self.gameMode = (kPoolOfLifeGameMode)value;
            break;
        default:
            break;
    }
}

#pragma mark -

-(void)update:(ccTime)delta
{
    self.currentTime += delta;
    //Check if it's time for the next grid update
    if(self.currentTime > self.nextUpdateTime)
    {
        if(!self.done)
        {
            //Perform the next step
            [self.game stepThroughCycle];
        }
        //Set the next update time
        ccTime nextDelta = /* ((arc4random() % 100) / 100.0f) **/ .15f;
        self.nextUpdateTime = self.currentTime + nextDelta;
        //NSLog(@"Next delta: %g, updating: %g", nextDelta, self.nextUpdateTime);
    }
    //React to touch input
    KKInput *input = [KKInput sharedInput];
    if(input.touchesAvailable && !self.optionsLayer.isLayerCurrentlyVisible)
    {
        KKTouch *touch;
        CCARRAY_FOREACH(input.touches, touch)
        {
            CGPoint touchLocation = touch.location;
            NSInteger row = touchLocation.y / self.cellWidth;
            NSInteger col = touchLocation.x / self.cellWidth;
            if(touch.phase == KKTouchPhaseBegan)
            {
                //Handle touches on the right button
                if(touchLocation.x >= self.widthWindow / 2 && touchLocation.y > self.heightGame + self.yOffset)
                {
                    self.done = !self.done;
                }
                //Handle touches on the left button
                else if(touchLocation.x < self.widthWindow / 2 && touchLocation.y > self.heightGame + self.yOffset)
                {
                    [self reset:YES];
                    /*
                    [self.optionsLayer layerWillAppear];
                    [self addChild:self.optionsLayer];
                     */
                }
            }
            if(row >= 0 && row < self.numRows && col >= 0 && col < self.numCols)
            {
                [self.game flipCellAtRow:row col:col started:(touch.phase == KKTouchPhaseBegan)];
            }
        }
    }
}

-(void) draw
{
    ccDrawSolidRect(CGPointMake(0, 0),
                    CGPointMake(self.widthGame, self.heightGame),
                    ccc4f(0, 1, 1, 1));
    
    //Set the color in RGB to draw the line with:
    ccDrawColor4B(100, 0, 255, 255); //purple, values range from 0 to 255
    
    //Draw row lines
    for(int row = 0; row < self.numRows; row ++)
    {
        //and now draw a line between them!
        ccDrawLine(CGPointMake(0,row * self.cellWidth),
                   CGPointMake(self.widthGame, row * self.cellWidth));
    }
    
    // Draw column lines
    for(int col = 0; col < self.numCols; col ++)
    {
        //and now draw a line between them!
        ccDrawLine(CGPointMake(col * self.cellWidth, 0),
                   CGPointMake(col * self.cellWidth, self.heightGame));
    }
    
    //Fill in active locations in the gameGrid
    for(int row = 0; row < self.numRows; row ++)
    {
        for(int col = 0; col < self.numCols; col ++)
        {
            NSInteger cellValue = [self.game cellAtRow:row col:col];
            NSInteger foodValue = [self.game foodAtRow:row col:col];
            if(cellValue || foodValue)
            {
                ccDrawSolidRect(CGPointMake(col * self.cellWidth, row * self.cellWidth),
                                CGPointMake((col + 1) * self.cellWidth, (row + 1) * self.cellWidth),
                                (cellValue ? CELL_COLOR : FOOD_COLOR));
            }
        }
    }
    
    //Draw the button
    ccDrawSolidRect(CGPointMake(self.widthWindow / 2, self.heightGame + self.yOffset),
                    CGPointMake(self.widthWindow, self.heightWindow),
                    self.toggleButtonColor);
    
    //Draw the clear button
    ccDrawSolidRect(CGPointMake(0, self.heightGame + self.yOffset),
                    CGPointMake(self.widthWindow / 2, self.heightWindow),
                    self.resetButtonColor);
}

@end
