import * as FsExtra from 'fs-extra';
import * as Winston from 'winston';
import * as Path from 'path';
import * as Uuid from 'uuid';
import * as Tar from 'tar';
import * as Minimist from 'minimist';
import * as Process from 'process';

const winston = Winston.createLogger({
    format: Winston.format.combine(
        Winston.format.splat(),
        Winston.format.simple(),
    ),
    transports: [new Winston.transports.Console()]
});
(<any> winston).level = 'debug';

async function extract(sourceFile: string, destinationFolder: string): Promise<string>{
    await Tar.extract({
        file: sourceFile,
        cwd: destinationFolder,
    });
    return destinationFolder;
}

async function copyUserScripts(sourceFolder: string, destinationFolder: string): Promise<string[]>{
    const returnValue = [];
    const sourceUserFolder = Path.resolve(sourceFolder, 'user');
    const destinationUserFolder = Path.resolve(destinationFolder, 'user');
    await FsExtra.ensureDir(destinationUserFolder);
    for ( let file of await FsExtra.readdir(sourceUserFolder)){
        if ( file.endsWith('.luas')){
            const baseName = Path.basename(file, '.luas');
            const destinationFile = Path.resolve(destinationUserFolder, `${baseName}.lua`);
            const sourceFile = Path.resolve(sourceUserFolder, file);
            winston.info('Copying %s from %s', baseName, sourceFile);
            await FsExtra.copy(sourceFile, destinationFile);
            returnValue.push(baseName);
        }
    }
    return returnValue;
}

async function updateFromZip(sourceFile: string){
    const destinationFolder = Path.resolve('temp', Uuid.v4());
    await FsExtra.mkdirp(destinationFolder);
    await extract(sourceFile, destinationFolder);
    winston.info('Extracted raw scripts to %s', destinationFolder);
    const workingFolder = Path.resolve('current');
    if ( await FsExtra.pathExists(workingFolder)){
        await FsExtra.remove(workingFolder);
    }
    await FsExtra.mkdirp(workingFolder);
    await copyUserScripts(destinationFolder, workingFolder);
}
let argv = Minimist(Process.argv.slice(2));
let sourceFile = `downloads/current.tar.gz`;
if ( argv._.length){
    sourceFile = argv._[0];
}
sourceFile = Path.resolve(sourceFile);
if ( !FsExtra.existsSync(sourceFile)){
    throw new Error(`Unable to find file ${sourceFile}`);
}
winston.info('About to process %s', sourceFile);
updateFromZip(sourceFile);