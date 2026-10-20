type Nullable<T> = T | null | undefined
declare function KtSingleton<T>(): T & (abstract new() => any);
export declare class SporeGame {
    constructor(levelJson: string, seed: number);
    get levelId(): string;
    get city(): string;
    get tutorial(): Nullable<string>;
    get columns(): number;
    get rows(): number;
    get activeTop(): number;
    get activeRows(): number;
    get moves(): number;
    get score(): number;
    get materialsLeft(): number;
    get materialsTotal(): number;
    get status(): string;
    get starScores(): Array<number>;
    stars(): number;
    cells(): Array<string>;
    marks(): Array<string>;
    swap(column: number, row: number, toColumn: number, toRow: number): string;
    get last(): string;
    set last(value: string);
    hint(): Array<number>;
}
export declare namespace SporeGame {
    /** @deprecated $metadata$ is used for internal purposes, please don't use it in your code, because it can be removed at any moment */
    namespace $metadata$ {
        const constructor: abstract new () => SporeGame;
    }
    abstract class Companion extends KtSingleton<Companion.$metadata$.constructor>() {
        private constructor();
    }
    namespace Companion {
        /** @deprecated $metadata$ is used for internal purposes, please don't use it in your code, because it can be removed at any moment */
        namespace $metadata$ {
            abstract class constructor {
                code(block: Nullable<any>/* Nullable<Block> */): string;
                private constructor();
            }
        }
    }
}